//
//  AudioPlaybackControllerTests.swift
//  ProsaryTests
//
//  The playback controller against the real narrated fixture
//  (Shared/tools/fixtures/kyrieaudiodemo.prosaryprayer, built by make-audio-fixture.sh):
//  pack → extract → AVAudioPlayer, chapter math, and transport — everything except audible
//  output, which stays paused so the suite runs silent.
//

import XCTest
@testable import Prosary

@MainActor
final class AudioPlaybackControllerTests: XCTestCase {
  private static let fixtureURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // ProsaryTests/
    .deletingLastPathComponent()  // iOS/
    .deletingLastPathComponent()  // repo root
    .appendingPathComponent("Shared/tools/fixtures/kyrieaudiodemo.prosaryprayer")

  private let bundleId = "kyrieaudiodemo"

  override func setUp() async throws {
    // On macOS the test host shares the real app's container — the fixture may already be
    // imported there for manual testing, which would make a bare install collide.
    PrayerPackStore.removeInstalledPack(id: bundleId)
    let data = try Data(contentsOf: Self.fixtureURL)
    try PrayerPackStore.installPack(from: data)
  }

  override func tearDown() async throws {
    PrayerPackStore.removeInstalledPack(id: bundleId)
  }

  func testFixtureDeclaresBothNarrations() throws {
    let tracks = PrayerPackStore.audioTracks(for: bundleId)
    XCTAssertEqual(tracks.map(\.id), ["la", "en"])
    XCTAssertEqual(tracks.map(\.language), ["la", "en"])
    for track in tracks {
      XCTAssertEqual(track.chapters.count, 5)
      XCTAssertEqual(track.chapters.map(\.stepIndex), [0, 1, 2, 3, 4])
      XCTAssertEqual(track.chapters.first?.start, 0)
      // Strictly increasing starts — the same invariant the format validator enforces.
      XCTAssertEqual(track.chapters.map(\.start), track.chapters.map(\.start).sorted())
    }
  }

  func testLoadsAndSeeksByChapter() throws {
    let track = try XCTUnwrap(PrayerPackStore.audioTracks(for: bundleId).first { $0.language == "la" })
    let controller = AudioPlaybackController()
    controller.load(bundleId: bundleId, track: track)

    XCTAssertTrue(controller.isLoaded)
    XCTAssertFalse(controller.isPlaying)
    XCTAssertEqual(controller.currentTime, 0)
    // The last chapter (the Gloria, ~9 s of narration) must fit AFTER its own start — the
    // original `duration > lastChapter.start` let a track truncated just past the final
    // boundary slide through ("it says 'Glo-' and stops").
    XCTAssertGreaterThan(controller.duration, track.chapters.last!.start + 5)
    XCTAssertLessThan(controller.duration, 60)
    XCTAssertEqual(controller.currentChapterIndex, 0)

    controller.seekToChapter(2)
    XCTAssertEqual(controller.currentTime, track.chapters[2].start, accuracy: 0.1)
    XCTAssertEqual(controller.currentChapterIndex, 2)

    // Just after a chapter starts, "previous" means "the chapter before this one"…
    controller.previousChapter()
    XCTAssertEqual(controller.currentChapterIndex, 1)

    // …but deep into one it means "restart this chapter".
    controller.seek(to: track.chapters[3].start + 3)
    XCTAssertEqual(controller.currentChapterIndex, 3)
    controller.previousChapter()
    XCTAssertEqual(controller.currentChapterIndex, 3)
    XCTAssertEqual(controller.currentTime, track.chapters[3].start, accuracy: 0.1)

    controller.nextChapter()
    XCTAssertEqual(controller.currentChapterIndex, 4)
    controller.nextChapter() // already the last chapter — stays put
    XCTAssertEqual(controller.currentChapterIndex, 4)

    controller.stop()
    XCTAssertFalse(controller.isLoaded)
    XCTAssertEqual(controller.currentTime, 0)
  }

  /// Real playback, end to end — the one test that catches under-scheduled audio. Playing the
  /// bundled .opus directly looked fine by every static measure (correct duration, full
  /// AVAudioFile decode) yet AVAudioPlayer's byte-estimated Ogg scheduling "finished" a 29 s
  /// narration at 20.6 s, cutting the Gloria off mid-word; only actually playing to the end
  /// distinguishes the CAF path from that. Costs real time (~6 s via rate 4) but guards the
  /// player's core promise.
  func testPlaysTheEntireTrackWithoutFinishingEarly() throws {
    let track = try XCTUnwrap(PrayerPackStore.audioTracks(for: bundleId).first { $0.language == "la" })
    let controller = AudioPlaybackController()
    controller.load(bundleId: bundleId, track: track)
    XCTAssertGreaterThan(controller.duration, 25) // full Latin narration ≈ 27.9 s

    controller.playPause()
    XCTAssertTrue(controller.isPlaying)
    controller.setPlaybackRate(4.0) // test-only fast-forward; pitch is irrelevant here

    let deadline = Date(timeIntervalSinceNow: controller.duration / 4 + 6)
    while controller.isPlaying, Date() < deadline {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
    }
    XCTAssertFalse(controller.isPlaying, "never finished — still at \(controller.currentTime)")
    XCTAssertEqual(controller.currentTime, controller.duration, accuracy: 0.5,
                   "finished early at \(controller.currentTime) of \(controller.duration)")
    controller.stop()
  }

  func testLoadingTheOtherLanguageSwapsTracks() throws {
    let tracks = PrayerPackStore.audioTracks(for: bundleId)
    let controller = AudioPlaybackController()
    controller.load(bundleId: bundleId, track: try XCTUnwrap(tracks.first { $0.language == "la" }))
    let latinDuration = controller.duration
    controller.load(bundleId: bundleId, track: try XCTUnwrap(tracks.first { $0.language == "en" }))
    XCTAssertTrue(controller.isLoaded)
    XCTAssertEqual(controller.track?.language, "en")
    XCTAssertEqual(controller.currentTime, 0)
    // Different narrations, different lengths — proves the swap actually reloaded.
    XCTAssertNotEqual(controller.duration, latinDuration)
  }
}
