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
    // Longer than the last chapter's start (the Gloria still has to be narrated after it),
    // shorter than a minute — sanity that the whole concatenated narration decoded.
    XCTAssertGreaterThan(controller.duration, track.chapters.last!.start)
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
