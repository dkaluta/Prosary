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

  func testHebrewDivineNamesAreSpokenAsAdonaiOrElohim() {
    XCTAssertEqual(PrayerSpeechController.spokenText("ה׳ לְעֶזְרָתִי חוּשָׁה", languageCode: "he"), "אֲדֹנָי לְעֶזְרָתִי חוּשָׁה")
    XCTAssertEqual(PrayerSpeechController.spokenText("שִׁפְחַת ה׳", languageCode: "he"), "שִׁפְחַת אֲדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("הִנֵּה יָמִים בָּאִים נְאֻם־יהוה", languageCode: "he"), "הִנֵּה יָמִים בָּאִים נְאֻם־אֲדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("כֹּה אָמַר אֲדֹנָי יהוה", languageCode: "he"), "כֹּה אָמַר אֲדֹנָי אֱלֹהִים")
    XCTAssertEqual(PrayerSpeechController.spokenText("אדני יהוה", languageCode: "he"), "אדני אֱלֹהִים")
    XCTAssertEqual(PrayerSpeechController.spokenText("אֲדֹנָי וַיהוה", languageCode: "he"), "אֲדֹנָי וֵאלֹהִים")
    XCTAssertEqual(PrayerSpeechController.spokenText("לַיהוה הָאָרֶץ", languageCode: "he"), "לַאדֹנָי הָאָרֶץ")
    XCTAssertEqual(PrayerSpeechController.spokenText("בַּיהוה חָסִיתִי", languageCode: "he"), "בַּאדֹנָי חָסִיתִי")
    XCTAssertEqual(PrayerSpeechController.spokenText("וַיהוה צִוָּה", languageCode: "he"), "וַאדֹנָי צִוָּה")
    XCTAssertEqual(PrayerSpeechController.spokenText("מֵיהוה", languageCode: "he"), "מֵאדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("לַה׳", languageCode: "he"), "לַאדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("יי", languageCode: "he"), "אֲדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("וַיי", languageCode: "he"), "וַאדֹנָי")
    XCTAssertEqual(PrayerSpeechController.spokenText("הוֹדוּ לַיהוָה כִּי־טוֹב", languageCode: "he"), "הוֹדוּ לַאדֹנָי כִּי־טוֹב")
  }
}
