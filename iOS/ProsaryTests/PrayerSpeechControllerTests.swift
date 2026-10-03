import XCTest
@testable import Prosary

@MainActor
final class PrayerSpeechControllerTests: XCTestCase {
  func testMatchesLanguageWithoutSubstitutingAnotherPrayerLanguage() {
    XCTAssertTrue(PrayerSpeechController.voiceMatches("en-GB", prayerLanguage: "en"))
    XCTAssertTrue(PrayerSpeechController.voiceMatches("he-IL", prayerLanguage: "he-x-gamliel"))
    XCTAssertTrue(PrayerSpeechController.voiceMatches("iw-IL", prayerLanguage: "he"))
    XCTAssertTrue(PrayerSpeechController.voiceMatches("fil-PH", prayerLanguage: "tl"))
    XCTAssertFalse(PrayerSpeechController.voiceMatches("en-US", prayerLanguage: "la"))
    XCTAssertFalse(PrayerSpeechController.voiceMatches("he-IL", prayerLanguage: "arc"))
    XCTAssertFalse(PrayerSpeechController.voiceMatches("en-US", prayerLanguage: ""))
  }

  func testSpeechPreservesThePrayerAndRemovesWeightMarkers() {
    XCTAssertEqual(PrayerSpeechController.spokenText("\nLeader.\n**Response.**\n"), "Leader.\nResponse.")
  }

  func testOlderAudioPacksRemainNarrationAndMusicHasAnExplicitRole() throws {
    let legacy = Data(#"{"id":"en","language":"en","file":"audio/en.opus","chapters":[{"start":0,"title":"Opening","stepIndex":0}]}"#.utf8)
    let decoder = JSONDecoder()
    XCTAssertTrue(try decoder.decode(DevotionAudioTrack.self, from: legacy).isNarration)
    let music = Data(#"{"id":"song","language":"en","file":"audio/song.opus","role":"music","chapters":[{"start":0,"title":"Opening song"}]}"#.utf8)
    let track = try decoder.decode(DevotionAudioTrack.self, from: music)
    XCTAssertTrue(track.isMusic)
    XCTAssertFalse(track.isNarration)
    XCTAssertNil(track.chapters.first?.stepIndex)
  }
}
