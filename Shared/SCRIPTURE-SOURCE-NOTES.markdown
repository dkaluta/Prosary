# Scripture source notes

On 27 September 2026 the user approved explicitly noting isolated unreadable vowel
marks in the Hebrew scans. This does not authorize missing words, unchecked pages,
invented verse boundaries, or guessed points. Preserve every readable printed mark;
omit only the unreadable mark and attach a visible source note to its exact unit.
An uncertain consonant normally remains an unresolved transcription finding.
On 2 October 2026 the user explicitly approved restoring the missing lamed in
Wisdom 1:16 with an editorial note. This is a separately disclosed restoration,
not a claim that the consonant is visible or a general license to complete damaged
words. Each further restoration needs its own recorded source evidence and editorial
decision; the ordinary point-omission rule does not approve it.

Later on 2 October 2026 the user explicitly approved three further contextual
restorations with visible notes: Wisdom 6:2 `הַאזינוּ` (alef and yod), Wisdom
16:23 `אולָם` (vav), and 2 Maccabees 14:4 `וְאֶחָת` (het). The surviving
printed points remain, including Second Maccabees' unusual segol. Unreadable
points have their own omission notes. These decisions are recorded in the final
restoration and root-acceptance reports; they do not authorize other reconstructions.

## Shared verse contract

An optional, nonempty `sourceNotes` array on a scripture verse contains objects with
exactly these fields:

```json
{
  "id": "lje-1-9-qoph-vowel",
  "kind": "unreadablePoint",
  "anchor": "בַּקּבָּה",
  "occurrence": 1,
  "letterIndex": 2,
  "mark": "vowel",
  "sourcePages": [16],
  "sourceURL": "https://example.org/source.pdf#page=16"
}
```

The example URL is illustrative, not a source citation. `anchor` is an exact substring
of the displayed primary text, including its retained points. `occurrence` is the
one-based, nonoverlapping occurrence of that substring. `letterIndex` counts Hebrew
letters U+05D0–U+05EA within the anchor, starting at one; it never counts combining
marks, UTF-16 units, punctuation or spaces. `mark` is `vowel`, `dagesh` or `shuruq`. A vowel note
normally requires all U+05B0–U+05BB and U+05C7 points absent on that letter; a dagesh note requires
U+05BC absent. A `shuruq` note likewise requires U+05BC absent, but may target only
the Hebrew letter vav (U+05D5). Its reader wording identifies a vowel omission,
not a dagesh omission. `retainedVowels` is forbidden for shuruq, even if null.
Dagesh and shuruq describe the same encoded dot, so two such notes on the same
letter are a duplicate, including with overlapping anchors. Other readable marks stay intact. Thus a provisional reading cannot
quietly survive beside a note saying it is unknown. These are Hebrew-source notes;
paired-script rows may not carry them until paired anchors have a defined contract.

One exception preserves a clearly readable companion vowel on the same letter, as
in a printed Jerusalem lamed with a separate hiriq and an unreadable qamats/patah.
The optional `retainedVowels` field is a one-item array containing that exact single
vowel scalar, for example `["ִ"]`. It is allowed only for `mark: "vowel"`. The actual
letter must contain exactly that one declared vowel and no other vowel code point;
absent means none. Empty/null arrays, repeated vowels, dagesh, nonvowels and strings
containing multiple scalars are invalid. Evidence must specifically establish the
retained point; this field cannot preserve a provisional guess. All readable marks
remain in the verse. The note still states that the unreadable point is omitted.

An explicitly reviewed consonant restoration uses the same required fields with
`kind: "restoredLetter"` and `mark: "consonant"`. Its `anchor` contains the restored
letter in the displayed text, and `letterIndex` identifies that exact Hebrew consonant.
For Wisdom 1:16 the anchor is `כּלְתָה`, index 2. The source preserves the sheva below
the missing consonant, so that readable point stays in the text. All independently
readable adjacent vowels and dageshes likewise remain. `retainedVowels` is forbidden
for this kind, even if null; that field describes the separate point-omission case.
The same word has a separate index-1 vowel-omission note for the unreadable kaf vowel.
Only these four kind/mark pairs are valid: `unreadablePoint/vowel`,
`unreadablePoint/dagesh`, `unreadablePoint/shuruq`, and `restoredLetter/consonant`.

IDs match `[a-z0-9][a-z0-9-]*` and are unique throughout the book. Pages are positive,
unique, ascending PDF page numbers and, in source authoring, a subset of the unit's
source pages. `sourceURL` must be HTTPS, without credentials. Every field in the example is required;
unknown kinds, mark categories, dangling anchors and invalid letter positions fail
validation rather than disappearing from the reader.

## Reader behavior

Every affected verse or supported textual block has a visible localized “Source note” indicator. Expanding it
shows the exact anchor, the affected letter and its position within that anchor,
whether the unreadable mark is a vowel (including shuruq) or dagesh, and the explicit statement that
the mark has been omitted. A restored-letter note instead explicitly says that the
identified consonant was restored editorially and is unreadable in the source scan;
it must never claim that the consonant was omitted or source-certified. Show the PDF
page number(s) and a link to the source scan.
The note is editorial, visually distinct from selectable scripture. It follows the
interface language; the quoted Hebrew follows Hebrew direction. Provide all eight
interface languages. The same verse representation is shared by Daily Readings and
the Bible reader, so both must render notes when present. Notes never change verse
navigation or get included in the verse's copied text.

## Versioning and review

Bible archives containing ordinary verse source notes use manifest and chapter `schemaVersion: 2`.
Their catalog edition declares `archiveSchemaVersion: 2`; absent means version 1.
The catalog root remains version 1. New readers accept archive versions 1 and 2,
require the manifest and every chapter to equal the edition's archive version, and
reject notes inside a version-1 archive. Older readers reject a version-2 manifest
instead of silently dropping its notes. Unknown archive versions are rejected.
Existing note-free archives remain byte-identical. Bundled daily readings remain
version 1 because their renderer ships with that exact dataset.

Archives with printed source blocks use version 3. Colophons may carry the same
precisely anchored source notes; these remain separate from their non-scripture
closing text and do not create verse choices. The generator preserves them and the
book-wide ID, page, digest and accepted-note review checks include them. Headings
remain note-free. The new optional colophon field and `shuruq` mark do not change
archive version numbers: older strict readers reject the unknown shape or mark
rather than discard the evidence; note-free archives remain byte-identical.

The source-book schema remains version 1 with this optional verse field. Notes enter
the full book content digest. A completed review separately lists its accepted note
IDs in `acceptedSourceNoteIds`; the approval inventory lists the same IDs as
`sourceNoteIds`. Both lists must exactly match the canonical notes. Evidence records
the affected crop, attempted readings, omission and the user's approved policy.
An accepted note is a deliberately disclosed source limitation; it is not an open
word or verse finding. A restoration's review evidence separately records the damaged
letter frame, readable points, comparative sources, and explicit editorial decision.
It does not turn contextual inference into visible print. All other review gates
continue to apply, including a complete
independent unit inventory and comparison of every page. The supplement remains
excluded until all twelve works are ready.
