import Foundation
import XCTest
@testable import Prosary

final class ScriptureSourceNoteTests: XCTestCase {
  private let anchor = "בַּקּבָּה"
  private func object(_ changes: [String: Any] = [:]) -> [String: Any] {
    var value: [String: Any] = ["id":"lje-1-9-qoph-vowel", "kind":"unreadablePoint", "anchor":anchor,
      "occurrence":1, "letterIndex":2, "mark":"vowel", "sourcePages":[16],
      "sourceURL":"https://example.org/source.pdf#page=16"]
    value.merge(changes) { _, new in new }
    return value
  }
  private func decode(_ value: [String: Any]) throws -> ScriptureSourceNote {
    try JSONDecoder().decode(ScriptureSourceNote.self, from: JSONSerialization.data(withJSONObject: value))
  }

  func testValidNoteCountsHebrewLettersAndPreservesReadableDagesh() throws {
    let note = try decode(object())
    XCTAssertTrue(note.isValid(in: "לפני \(anchor) אחרי"))
    XCTAssertEqual(note.affectedLetter, "קּ")
    XCTAssertEqual(note.sourceLink?.fragment, "page=16")
    XCTAssertEqual(note.sourcePages, [16])
  }

  func testShuruqTargetsVavAndCannotHideOrDoubleCountTheDot() throws {
    let changes: [String: Any] = ["anchor":"ו", "letterIndex":1, "occurrence":2, "mark":"shuruq"]
    let note = try decode(object(changes))
    XCTAssertTrue(note.isValid(in: "וּ ו"))
    XCTAssertFalse(note.isValid(in: "ו וּ"), "A short anchor cannot conceal the retained dot")
    XCTAssertFalse(try decode(object(["anchor":"ב", "letterIndex":1, "mark":"shuruq"])).isValid(in: "ב"))
    for retained: Any in [NSNull(), [String](), ["ְ"]] {
      var fields = changes; fields["retainedVowels"] = retained
      XCTAssertThrowsError(try decode(object(fields)))
    }
    XCTAssertThrowsError(try decode(object(["kind":"restoredLetter", "mark":"shuruq"])))
    let dagesh = try decode(object(["anchor":"ו", "letterIndex":1, "occurrence":2, "mark":"dagesh"]))
    XCTAssertEqual(note.position(in: "וּ ו"), dagesh.position(in: "וּ ו"))
  }

  func testExactNonoverlappingAnchorOccurrencesAndScalarIndex() throws {
    let note = try decode(object(["occurrence":2]))
    XCTAssertTrue(note.isValid(in: "\(anchor) \(anchor)"))
    XCTAssertFalse(note.isValid(in: anchor))
    let overlapping = try decode(object(["anchor":"אא", "letterIndex":1, "occurrence":2]))
    XCTAssertFalse(overlapping.isValid(in: "אאא"))
    XCTAssertTrue(overlapping.isValid(in: "אאאא"))
    let punctuation = try decode(object(["anchor":"[בַּ־קּ]", "letterIndex":2]))
    XCTAssertEqual(punctuation.affectedLetter, "קּ")
    XCTAssertTrue(punctuation.isValid(in: "[בַּ־קּ]"))
    let decomposed = try decode(object(["anchor":"ב\u{05BC}\u{05B7}קּבָּה"]))
    XCTAssertFalse(decomposed.isValid(in: anchor), "Canonical equivalence is not an exact source anchor")
  }

  func testRejectsMalformedAnchorsPagesURLsAndLetterPositions() throws {
    for changes: [String: Any] in [["id":"Bad ID"], ["anchor":""], ["anchor":"missing"],
      ["occurrence":0], ["occurrence":2], ["letterIndex":0], ["letterIndex":5],
      ["sourcePages":[]], ["sourcePages":[0]], ["sourcePages":[16,16]], ["sourcePages":[17,16]],
      ["sourceURL":"http://example.org/source"], ["sourceURL":"https://name:secret@example.org/source"]] {
      XCTAssertFalse(try decode(object(changes)).isValid(in: anchor), "\(changes)")
    }
    for changes: [String: Any] in [["kind":"other"], ["mark":"accent"], ["extra":"ignored"], ["occurrence":true]] {
      XCTAssertThrowsError(try decode(object(changes)), "\(changes)")
    }
    var missing = object(); missing.removeValue(forKey: "sourcePages")
    XCTAssertThrowsError(try decode(missing))
  }

  func testCannotRetainGuessedVowelOrDageshBesideOmissionNote() throws {
    for scalar in Array(0x05B0...0x05BB) + [0x05C7] {
      let pointed = "ק" + String(Unicode.Scalar(scalar)!)
      XCTAssertFalse(try decode(object(["anchor":pointed,"letterIndex":1])).isValid(in: pointed))
    }
    XCTAssertFalse(try decode(object(["mark":"dagesh"])).isValid(in: anchor))
    let readableVowel = "קָ"
    XCTAssertTrue(try decode(object(["anchor":readableVowel,"letterIndex":1,"mark":"dagesh"])).isValid(in: readableVowel))
    let shortened = try decode(object(["anchor":"ק","letterIndex":1]))
    XCTAssertFalse(shortened.isValid(in: "קָ"), "A truncated quote cannot hide a retained guessed mark")
    XCTAssertTrue(shortened.isValid(in: "קּ"), "A readable dagesh remains compatible with an omitted vowel")
  }

  func testDailyPassageAcceptsValidNotesButRejectsEmptyPairedAndDuplicateNotes() throws {
    func dataset(notes: Any, paired: Bool = false, duplicate: Bool = false) throws -> ReadingTextDataset {
      var verse: [String: Any] = ["chapter":1,"verse":9,"text":anchor,"sourceNotes":notes]
      if paired { verse["transliteratedText"] = "ܐ" }
      let value: [String: Any] = ["schemaVersion":1,"editions":[["id":"test","languageCode":"he","name":"Test","attribution":"Source","sourceURL":"https://example.org"]],
        "passages":["daily|Test 1:9":["test":duplicate ? [verse,verse] : [verse]]]]
      return try JSONDecoder().decode(ReadingTextDataset.self, from: JSONSerialization.data(withJSONObject: value))
    }
    let good = try dataset(notes:[object()]).passage(citation:"Test 1:9",isTorah:false,editionID:"test")
    XCTAssertEqual(good?.verses.first?.text, anchor, "Editorial text is not appended to copied scripture")
    XCTAssertEqual(good?.verses.first?.sourceNotes?.first?.id, "lje-1-9-qoph-vowel")
    for bad in [try dataset(notes:[]),
                try dataset(notes:[object()],duplicate:true), try dataset(notes:[object(["anchor":"missing"])] ),
                try dataset(notes:[object(),object(["id":"different-id","anchor":"קּבָּה","letterIndex":1])])] {
      XCTAssertNil(bad.passage(citation:"Test 1:9",isTorah:false,editionID:"test"))
    }
    XCTAssertThrowsError(try dataset(notes:NSNull()))
    XCTAssertThrowsError(try dataset(notes:[object()],paired:true))
  }

  func testRetainedVowelPreservesOnlyTheDeclaredReadableCompanionPoint() throws {
    let text = "יְרוּשָׁלִם"
    let valid = object(["anchor":text,"letterIndex":5,"retainedVowels":["ִ"]])
    let note = try decode(valid)
    XCTAssertTrue(note.isValid(in:text))
    XCTAssertEqual(note.affectedLetter,"לִ")
    XCTAssertFalse(try decode(object(["anchor":text,"letterIndex":5])).isValid(in:text))
    XCTAssertFalse(note.isValid(in:"יְרוּשָׁלִַם"), "The unresolved companion vowel must not survive")
    XCTAssertFalse(try decode(object(["anchor":"לם","letterIndex":1,"retainedVowels":["ִ"]])).isValid(in:"לם"))
    let shortened = try decode(object(["anchor":"ל","letterIndex":1,"retainedVowels":["ִ"]]))
    XCTAssertTrue(shortened.isValid(in:"לִ"), "Validate the full resolved source letter")
    XCTAssertFalse(shortened.isValid(in:"לִָ"))
    XCTAssertFalse(shortened.isValid(in:"לִִ"), "Duplicate source scalars are not one retained point")
    for retained in [[],["ִ","ִ"],["ִ","ַ"],["ִַ"],["ּ"],["א"],[""]] {
      XCTAssertFalse(try decode(object(["anchor":text,"letterIndex":5,"retainedVowels":retained])).isValid(in:text), "\(retained)")
    }
    XCTAssertFalse(try decode(object(["anchor":text,"letterIndex":5,"mark":"dagesh","retainedVowels":["ִ"]])).isValid(in:text))
    XCTAssertThrowsError(try decode(object(["retainedVowels":NSNull()])))
  }

  func testRestoredLetterPreservesReadablePointsAndExactSourceAnchor() throws {
    let text = "כָּלְתָה"
    let value = object(["kind":"restoredLetter", "mark":"consonant", "anchor":text, "letterIndex":2])
    let note = try decode(value)
    XCTAssertTrue(note.isValid(in:text))
    XCTAssertEqual(note.affectedLetter, "לְ")
    XCTAssertEqual(note.sourceLink?.fragment, "page=16")
    XCTAssertFalse(note.isValid(in:"כָּלָתָה"), "Restoration does not relax exact pointed anchors")

    let pointedLetter = "לְּ"
    let pointed = try decode(object(["kind":"restoredLetter", "mark":"consonant", "anchor":pointedLetter, "letterIndex":1]))
    XCTAssertTrue(pointed.isValid(in:pointedLetter), "A consonant restoration preserves both readable vowel and dagesh")
    XCTAssertEqual(pointed.affectedLetter, pointedLetter)
    for changes: [String: Any] in [["letterIndex":5], ["sourcePages":[]], ["sourceURL":"http://example.org"], ["id":"Bad ID"]] {
      XCTAssertFalse(try decode(value.merging(changes) { _, new in new }).isValid(in:text))
    }
  }

  func testRestorationRejectsOmissionMarksAndRetainedVowelsField() throws {
    for changes: [String: Any] in [
      ["kind":"restoredLetter", "mark":"vowel"],
      ["kind":"restoredLetter", "mark":"dagesh"],
      ["kind":"unreadablePoint", "mark":"consonant"]
    ] {
      XCTAssertThrowsError(try decode(object(changes)), "\(changes)")
    }
    for retained: Any in [[], ["ְ"], NSNull()] {
      XCTAssertThrowsError(try decode(object(["kind":"restoredLetter", "mark":"consonant", "retainedVowels":retained])),
                           "The retainedVowels field is forbidden on a consonant restoration, even when empty or null")
    }
  }
}
