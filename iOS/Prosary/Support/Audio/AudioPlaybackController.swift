//
//  AudioPlaybackController.swift
//  Prosary
//
//  Plays one bundle audio track (see Shared/ARCHITECTURE.md "Audio"): extracts the Ogg Opus
//  bytes from the pack into Caches (recordings dwarf every other bundle asset, so they are
//  never held in memory), opens them with AVAudioPlayer — directly where the OS demuxes .opus
//  (current OSes), via the lossless OggOpusCAF repackage where it doesn't (the iOS 17/macOS 14
//  deployment floor) — and publishes time/chapter state for the prayer flow's audio bar.
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

  // MARK: Loading

  /// Extracts and opens the track; leaves the player paused at 0. Any previous track stops.
  func load(bundleId: String, track: DevotionAudioTrack) {
    stop()
    guard let url = Self.extractedFileURL(bundleId: bundleId, track: track),
          let opened = Self.openPlayer(for: url) else { return }
    opened.delegate = self
    opened.prepareToPlay()
    player = opened
    duration = opened.duration
    currentTime = 0
    self.track = track
  }

  /// The cached audio file for a track, extracting from the pack on first use. Returns the
  /// .opus path; `openPlayer` decides whether a CAF sibling is needed.
  private static func extractedFileURL(bundleId: String, track: DevotionAudioTrack) -> URL? {
    guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let dir = caches.appendingPathComponent("PrayerAudio/\(bundleId)", isDirectory: true)
    let url = dir.appendingPathComponent((track.file as NSString).lastPathComponent)
    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 {
      return url
    }
    guard let data = PrayerPackStore.audioData(bundleId: bundleId, file: track.file) else { return nil }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
    return url
  }

  /// Direct .opus open where the OS supports it; otherwise the CAF repackage (cached beside
  /// the .opus so the conversion happens once per track, not once per session).
  private static func openPlayer(for opusURL: URL) -> AVAudioPlayer? {
    if let direct = try? AVAudioPlayer(contentsOf: opusURL) { return direct }
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
    player?.stop()
    player = nil
    track = nil
    isPlaying = false
    currentTime = 0
    duration = 0
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
    }
  }
}
