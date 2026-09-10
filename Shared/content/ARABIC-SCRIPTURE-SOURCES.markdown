# Old Jesuit Arabic Scripture

Prosary's Arabic Scripture excerpts use the old Jesuit translation, independently
transcribed from the **1897 Beirut printing** of *الكتاب المقدس*. The modern Jesuit
revision previously credited to Dar el-Machreq is no longer the source of these
passages. Fixed prayers and authored meditations retain their separate provenance.

## Printed source

- Publisher: مطبعة المرسلين اليسوعيين ببيروت, Jesuit Press, Beirut.
- Printing: 1897, visible on the original title page (PDF page 7).
- Original approval: Beirut, 3 November 1897, on PDF page 9.
- [Digitized volume at Internet Archive](https://archive.org/details/AlKitabAlMoqadas).
- [Source PDF](https://archive.org/download/AlKitabAlMoqadas/AlKitabAlMoqadas.pdf):
  570 pages; SHA-256
  `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.

The nineteenth-century biblical text is public domain. The app bundles the new
transcription of that printed text, not the scan, its uploader's metadata, or
modern editorial material. The archive uploader's separate scan-license label
does not serve as the source license for this transcription. A second volume
advertised online as “1877” contains a 1939 New Testament title page; that
listing's date was not used to identify the source.

## Transcription and coverage

`arabic-jesuit-1897.json` contains 220 distinct verses, each with its one-based PDF
page number or page numbers. Each passage was visually transcribed and then read
against the scan independently. OCR served only to locate pages. Wording and
printed verse boundaries are retained; vowel marks, shadda, typographic ornaments,
and footnote markers are omitted. Whitespace and punctuation are normalized;
hamza typography uses ordinary Unicode letters. Historical words and spellings
such as `خطية`, `مومن`, and `نيقودمس` remain.

These verses replace 68 Scripture fields across Rosary, Seven Sorrows, Franciscan
Crown, Via Lucis, and Stations of the Cross. The three native Rosary fallback
tables are generated from the same canonical descriptions. The fourth Seven
Sorrows meditation is authored prose and is not replaced; an absent traditional
Stations body is not invented. Complete cited verses replace formerly truncated
descriptions, and explicit gaps between cited ranges carry `[…]`.

This is a reviewed excerpt corpus, **not a complete Arabic Bible**. The offline
readings builder uses only entire reviewed passage units whose verses are all
available. It cannot slice unreviewed subsets, fill gaps from another translation,
or treat old verse numbers as proof of modern verse boundaries. For example,
Luke 1:32–33 and 22:43–44 divide their text differently in this printing.

## Updating the content

1. Verify any new passage against the printed source; record its PDF pages and
   complete passage unit in `arabic-jesuit-1897.json`.
2. Keep the explicit replacement inventory in
   `../tools/arabic-scripture-passages.json` consistent with the cited fields.
3. Run `uv run --script Shared/tools/import-arabic-scripture.py` from the repository
   root, followed by its `--check` mode and `test-import-arabic-scripture.py`.
4. Regenerate the affected packs with `Shared/tools/make-prosaryprayer.sh` and copy
   the generated archives to all three native asset directories. Run
   `test-asset-deduplication.py` and `audit-prayer-coverage.py`.
5. After reviewed source changes, update its checksum in
   `Shared/tools/reading-text-sources.json`, then regenerate and sync offline
   readings with `build-reading-texts.py --sync` and run the reading tests.

About credits identify the old 1897 Jesuit edition in all eight interface
languages. The separate Dar el-Machreq credit for localized Bible **book names**
remains: changing the verse edition does not change that metadata source.
