//
//  AudioPlaybackController.swift
//  Prosary
//
//  Plays one bundle audio track (see Shared/ARCHITECTURE.markdown "Audio"): extracts the Ogg Opus
//  bytes from the pack into Caches with bounded streaming (recordings dwarf every other bundle
//  asset, so they are never retained in the content store), losslessly wraps the recording in
//  CAF for accurate cross-version scheduling, and publishes time/chapter state for the prayer
//  flow's audio bar.
//  Chapter → step syncing itself lives in the flow view, because only it knows the built step
//  sequence the chapters' advisory stepIndex hints point into.
//

import AVFoundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class AudioPlaybackController: NSObject, AVAudioPlayerDelegate {
  private(set) var track: DevotionAudioTrack?
  private(set) var isPlaying = false
  private(set) var currentTime: Double = 0
  private(set) var duration: Double = 0
  /// True when `load` resumed a previous session's position — the flow then skips its
  /// align-to-step-0 and lets the chapter sync pull the page to the restored chapter instead.
  private(set) var didRestorePosition = false
  /// Nil while no track is loaded (the flow omits its audio bar entirely).
  var isLoaded: Bool { player != nil }

  /// Index into `track.chapters` of the chapter `currentTime` falls in.
  var currentChapterIndex: Int? {
    guard let chapters = track?.chapters, !chapters.isEmpty else { return nil }
    // A hair of tolerance so landing exactly on a boundary via seekToChapter counts as being
    // in that chapter despite floating-point time.
    return (chapters.lastIndex { $0.start <= currentTime + 0.01 }) ?? 0
  }

  private var player: AVAudioPlayer?
  private var ticker: Timer?
  /// UserDefaults key for the loaded track's saved position — track ids are unique within a
  /// bundle (the format reserved them for exactly this).
  private var positionKey: String?

  /// A stored position worth resuming: past the first moments (a fresh start isn't a
  /// "session"), short of the last stretch (a nearly-finished listen restarts instead).
  /// Shared rule across platforms.
  static func shouldRestore(position: Double, duration: Double) -> Bool {
    position > 10 && duration > 0 && position < duration * 0.9
  }

  // MARK: Loading

  /// Extracts and opens the track; leaves the player paused at 0. Any previous track stops.
  func load(bundleId: String, track: DevotionAudioTrack) {
    stop()
    guard let url = Self.extractedFileURL(bundleId: bundleId, track: track),
          let opened = Self.openPlayer(for: url) else { return }
    opened.delegate = self
    opened.enableRate = true // must precede prepareToPlay; lets setPlaybackRate work later
    opened.prepareToPlay()
    player = opened
    duration = opened.duration
    currentTime = 0
    self.track = track

    // Resume where the last session left off (positions persist per track id).
    positionKey = "audioPosition.\(bundleId).\(track.id)"
    let saved = UserDefaults.standard.double(forKey: positionKey!)
    didRestorePosition = Self.shouldRestore(position: saved, duration: duration)
    if didRestorePosition {
      opened.currentTime = saved
      currentTime = opened.currentTime
    }
  }

  /// Persists the position (or clears it near the edges, so finished/abandoned-at-start
  /// sessions begin fresh next time). Called on pause, stop, and natural finish.
  private func savePosition() {
    guard let positionKey else { return }
    if Self.shouldRestore(position: currentTime, duration: duration) {
      UserDefaults.standard.set(currentTime, forKey: positionKey)
    } else {
      UserDefaults.standard.removeObject(forKey: positionKey)
    }
  }

  /// The cached audio file for a track, extracting from the pack on first use. Returns the
  /// .opus path; `openPlayer` decides whether a CAF sibling is needed.
  private static func extractedFileURL(bundleId: String, track: DevotionAudioTrack) -> URL? {
    guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    guard let cacheKey = PrayerPackStore.audioCacheKey(bundleId: bundleId, file: track.file) else {
      return nil
    }
    let dir = caches.appendingPathComponent("PrayerAudio/\(bundleId)", isDirectory: true)
    let sourceName = (track.file as NSString).lastPathComponent
    let sourceExtension = (sourceName as NSString).pathExtension
    let sourceStem = (sourceName as NSString).deletingPathExtension
    let cacheName = "\(sourceStem)--\(cacheKey).\(sourceExtension)"
    let url = dir.appendingPathComponent(cacheName)
    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
      return url
    }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard PrayerPackStore.extractAudioFile(bundleId: bundleId, file: track.file, to: url) else {
      return nil
    }
    // Cache storage is disposable, but a user may replace a same-id pack many times. Keep only
    // this recording's current content-addressed Opus/CAF pair (and remove the legacy basename).
    let currentStem = (cacheName as NSString).deletingPathExtension
    if let cachedFiles = try? FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: nil)
    {
      for cached in cachedFiles {
        let name = cached.lastPathComponent
        let stem = (name as NSString).deletingPathExtension
        let isLegacy = name == sourceName || name == "\(sourceStem).caf"
        let isOlderRevision = stem.hasPrefix("\(sourceStem)--") && stem != currentStem
        if isLegacy || isOlderRevision { try? FileManager.default.removeItem(at: cached) }
      }
    }
    return url
  }

  /// Always plays through the CAF repackage (cached beside the .opus, converted once per
  /// track). Never the .opus directly: the deployment floor (iOS 17/macOS 14) can't demux
  /// bare Ogg at all, and where newer OSes can, AVAudioPlayer's Ogg scheduling is byte-rate
  /// *estimated* — measured on macOS 26, a 29 s VBR narration "finishes successfully" after
  /// 20.6 s, cutting the last section off mid-word, and seeks land off target the same way.
  /// The CAF's explicit packet table plays and seeks exactly, and identically on every OS.
  private static func openPlayer(for opusURL: URL) -> AVAudioPlayer? {
    let cafURL = opusURL.deletingPathExtension().appendingPathExtension("caf")
    if let cached = try? AVAudioPlayer(contentsOf: cafURL) { return cached }
    guard let ogg = try? Data(contentsOf: opusURL),
          let caf = try? OggOpusCAF.repackage(ogg),
          (try? caf.write(to: cafURL, options: .atomic)) != nil else { return nil }
    return try? AVAudioPlayer(contentsOf: cafURL)
  }

  // MARK: Transport

  func playPause() {
    guard let player else { return }
    if player.isPlaying {
      player.pause()
      isPlaying = false
      stopTicker()
      currentTime = player.currentTime
      savePosition()
    } else {
      #if canImport(UIKit) && !os(watchOS)
      // Prayer audio should sound with the ringer switch silenced, like any audiobook.
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
      try? AVAudioSession.sharedInstance().setActive(true)
      #endif
      // Finished-and-restarted: tapping play at the end starts over instead of doing nothing.
      if duration > 0, player.currentTime >= duration - 0.05 { player.currentTime = 0 }
      player.play()
      isPlaying = true
      startTicker()
    }
    currentTime = player.currentTime
  }

  /// Playback rate multiplier (1 = normal). No UI surfaces this yet — the full-length
  /// playback test uses it to fast-forward through a real narration.
  func setPlaybackRate(_ rate: Float) {
    player?.rate = rate
  }

  func seek(to time: Double) {
    guard let player else { return }
    player.currentTime = max(0, min(time, duration))
    currentTime = player.currentTime
  }

  func seekToChapter(_ index: Int) {
    guard let chapters = track?.chapters, chapters.indices.contains(index) else { return }
    seek(to: chapters[index].start)
  }

  /// Back within a chapter's first moments goes to the previous chapter (the audiobook
  /// convention); later in a chapter it restarts the chapter.
  func previousChapter() {
    guard let index = currentChapterIndex else { return }
    let restartThreshold = (track?.chapters[index].start ?? 0) + 2
    seekToChapter(currentTime < restartThreshold ? max(index - 1, 0) : index)
  }

  func nextChapter() {
    guard let index = currentChapterIndex, let chapters = track?.chapters else { return }
    if index + 1 < chapters.count { seekToChapter(index + 1) }
  }

  func stop() {
    if let player {
      currentTime = player.currentTime
      savePosition()
    }
    player?.stop()
    player = nil
    track = nil
    isPlaying = false
    currentTime = 0
    duration = 0
    didRestorePosition = false
    positionKey = nil
    stopTicker()
    #if canImport(UIKit) && !os(watchOS)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    #endif
  }

  // MARK: Time publishing

  /// AVAudioPlayer has no periodic observer, so a coarse timer mirrors its clock into the
  /// observable `currentTime` while playing — 4 Hz is plenty for a progress bar and chapter
  /// boundaries, and costs nothing while paused (the ticker only runs during playback).
  private func startTicker() {
    stopTicker()
    ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, let player = self.player else { return }
        self.currentTime = player.currentTime
      }
    }
  }

  private func stopTicker() {
    ticker?.invalidate()
    ticker = nil
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in
      isPlaying = false
      currentTime = duration
      stopTicker()
      savePosition() // at duration this clears the key — a finished listen restarts fresh
    }
  }
}
