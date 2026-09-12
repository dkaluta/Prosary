#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["beautifulsoup4>=4.12,<5", "requests>=2.32,<3"]
# ///
"""Offline numeric scraper regressions. Fixtures contain no biblical wording."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("nabre_fetch", Path(__file__).with_name("fetch-nabre-versification.py"))
fetch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fetch)


def verse(label: str, text: str = "Synthetic fixture") -> str:
    body = f'<span class="txt">{text}</span>' if text else ""
    return f'<span class="verse"><span class="bcv">{label}</span>{body}</span>'


def page(content: str, heading: str = "CHAPTER 1") -> bytes:
    return f'<main><h3>{heading}</h3>{content}</main>'.encode()


def browser_fixture() -> dict:
    return {"indexURL": fetch.INDEX_URL, "books": [{
        "code": "GEN", "slug": "genesis", "indexURL": "https://bible.usccb.org/bible/genesis/0",
        "pageOrder": ["1", "2"], "pages": [{
            "label": "1", "url": "https://bible.usccb.org/bible/genesis/1",
            "chapters": [{"label": "1", "maximum": 3}],
        }],
    }], "errors": []}


class ParserTests(unittest.TestCase):
    def parse(self, body: bytes) -> dict:
        return fetch.parse_chapter_page(body, "https://bible.usccb.org/bible/genesis/1/", "1")

    def test_index_requires_all_73_known_books_without_using_menu_order_as_numbering(self):
        body = "".join(f'<a href="/bible/book{i}/0">{name}</a>' for i, name in enumerate(fetch.BOOK_NAMES))
        books = fetch.parse_book_index(body.encode())
        self.assertEqual(list(books), fetch.BOOK_CODES)
        self.assertEqual(len(books), 73)
        self.assertEqual(books["GEN"]["slug"], "book0")
        with self.assertRaisesRegex(fetch.InventoryError, "incomplete-book-index"):
            fetch.parse_book_index(b'<a href="/bible/genesis/0">Genesis</a>')

    def test_chapter_navigation_excludes_note_links_and_other_books(self):
        body = b'''<nav><a href="/bible/esther/1">1</a><a href="/bible/esther/2">2</a>
        <a href="/bible/esther/A">A</a></nav><a href="/bible/esther/1?2">2</a>
        <a href="/bible/genesis/3">3</a><a href="/bible/esther/2#note">2</a>'''
        self.assertEqual(fetch.parse_chapter_index(body, "esther", "https://bible.usccb.org/bible/esther/0"), ["1", "2", "A"])

    def test_numeric_labels_have_no_prose_and_source_hash_is_reproducible(self):
        body = page(verse("1", "A synthetic alpha") + verse("2", "Another synthetic beta"))
        result = self.parse(body)
        chapter = result["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["1", "2"])
        self.assertEqual(chapter["sourcePages"][0]["sha256"], fetch.digest(body))
        self.assertNotIn("synthetic", json.dumps(result))
        self.assertNotIn("alpha", json.dumps(result))

    def test_omission_markers_are_distinct_from_bracketed_text_and_unprinted_gaps(self):
        body = page(verse("1") + verse("[2]", "") + verse("4", "[Synthetic fixture bracket]")
                    + '<div class="footnotes">Synthetic note 2.</div>')
        chapter = self.parse(body)["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["1", "4"])
        self.assertEqual(chapter["omittedVerses"], ["2"])
        self.assertNotIn("3", chapter["omittedVerses"], "A numerical gap alone is not an explicit omission marker")

    def test_relocated_duplicate_split_and_grouped_labels_are_never_renumbered(self):
        order = ["1", "3", "2", "2", "4a", "4b", "5-6"]
        chapter = self.parse(page("".join(verse(v) for v in order)))["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], order)
        self.assertEqual(chapter["duplicateVerses"], ["2"])

    def test_esther_letter_sections_retain_document_order(self):
        body = ('<main><div class="alphchapter"><p class="chapterhead" id="19041000">CHAPTER A</p>'
                + verse("1") + verse("2") + '</div><h3>CHAPTER 1</h3>' + verse("1") + '</main>').encode()
        result = self.parse(body)
        self.assertEqual(result["chapterOrder"], ["A", "1"])
        self.assertEqual(result["chapters"]["A"]["verseOrder"], ["1", "2"])

    def test_selected_chapter_one_index_restores_plain_navigation_entry(self):
        body = b'<h3>CHAPTER 1</h3><a href="/bible/2samuel/2">2</a>'
        self.assertEqual(fetch.parse_chapter_index(body, "2samuel", "https://bible.usccb.org/bible/2samuel/1"), ["1", "2"])

    def test_one_chapter_book_uses_its_observed_url_with_an_unnumbered_heading(self):
        body = page(verse("1") + verse("2"), "CHAPTER")
        self.assertEqual(fetch.parse_chapter_index(body, "jude", "https://bible.usccb.org/bible/jude/1"), ["1"])
        with self.assertRaises(fetch.InventoryError):
            fetch.parse_chapter_index(b'<h3>CHAPTER</h3><p>Not a verse inventory</p>',
                                      "jude", "https://bible.usccb.org/bible/jude/1")

    def test_table_cell_markers_are_part_of_the_chapter_inventory(self):
        body = page('<table><tr><td><span class="bcv">1</span></td><td>Synthetic cell alpha</td></tr>'
                    '<tr><td><span class="bcv">2</span></td><td>Synthetic cell beta</td></tr></table>')
        self.assertEqual(self.parse(body)["chapters"]["1"]["verseOrder"], ["1", "2"])

    def test_named_anchors_restore_cross_page_chapter_identifiers(self):
        body = page('<a name="23009035"></a>' + verse("35")
                    + '<a name="23010001"></a>' + verse("1"), "CHAPTER 9")
        result = fetch.parse_chapter_page(body, "https://bible.usccb.org/bible/job/9", "9")
        self.assertEqual(result["chapterOrder"], ["9", "10"])
        self.assertEqual(result["chapters"]["10"]["verseOrder"], ["1"])

    def test_esther_anchor_restores_numeric_chapter_after_an_addition(self):
        body = ('<h3>CHAPTER B</h3><a name="19042007"></a>' + verse("7")
                + '<a name="19003014"></a>' + verse("14") + verse("15")).encode()
        result = fetch.parse_chapter_page(body, "https://bible.usccb.org/bible/esther/B", "B")
        self.assertEqual(result["chapterOrder"], ["B", "3"])
        self.assertEqual(result["chapters"]["3"]["verseOrder"], ["14", "15"])

    def test_older_unwrapped_anchors_and_normal_spans_can_share_a_page(self):
        body = page('<a name="13001001">Synthetic plain alpha</a>'
                    + '<a name="13001002">Synthetic plain beta</a>'
                    + '<a name="13001003"></a>' + verse("3"))
        self.assertEqual(self.parse(body)["chapters"]["1"]["verseOrder"], ["1", "2", "3"])

    def test_anchor_body_with_bcv_needs_no_verse_or_txt_wrapper(self):
        body = page('<p><a name="01001001"><span class="bcv">1</span>Synthetic anchor body</a>'
                    '<a name="01001002"><span class="bcv">2</span>Synthetic second body</a></p>')
        self.assertEqual(self.parse(body)["chapters"]["1"]["verseOrder"], ["1", "2"])

    def test_plain_continuation_anchors_do_not_duplicate_the_same_bcv_verse(self):
        body = page('<p><a name="01001001"><span class="bcv">1</span>Synthetic first half</a></p>'
                    '<p><a name="01001001">Synthetic continuation</a></p>'
                    '<a name="01001002">Synthetic prefix</a>' + verse("2"))
        chapter = self.parse(body)["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["1", "2"])
        self.assertEqual(chapter["duplicateVerses"], [])

    def test_direct_paragraph_body_does_not_require_a_txt_span(self):
        body = page('<p><span class="bcv">1</span>Synthetic direct body '
                    '<span class="bcv">2</span>Synthetic second body</p>')
        self.assertEqual(self.parse(body)["chapters"]["1"]["verseOrder"], ["1", "2"])

    def test_note_labels_and_the_next_verse_do_not_fill_an_empty_marker(self):
        body = page('<p><span class="bcv">1</span><sup><a href="#note">a</a></sup>'
                    '<a name="01001002"></a><span class="bcv">2</span>Synthetic body</p>')
        chapter = self.parse(body)["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["2"])
        self.assertEqual(chapter["omittedVerses"], ["1"])

    def test_explicit_cross_chapter_marker_changes_the_following_unanchored_context(self):
        body = page(verse("9") + verse("2:1") + verse("2"))
        result = self.parse(body)
        self.assertEqual(result["chapters"]["2"]["verseOrder"], ["1", "2"])

    def test_navigation_footnotes_and_crossreferences_cannot_add_verse_numbers(self):
        body = page(verse("1") + '<nav>' + verse("90") + '</nav>'
                    + '<div class="footnotes">' + verse("91") + '</div>'
                    + '<footer>' + verse("92") + '</footer>')
        self.assertEqual(self.parse(body)["chapters"]["1"]["verseOrder"], ["1"])

    def test_unknown_markup_and_missing_requested_chapter_fail_closed(self):
        for body in [b'<h1>Checking connection</h1>', page('<span>1</span> Synthetic'), page(verse("1"), "CHAPTER 2")]:
            with self.subTest(body=body), self.assertRaises(fetch.InventoryError):
                self.parse(body)

    def test_marker_prose_is_rejected_instead_of_ever_serialized(self):
        with self.assertRaisesRegex(fetch.InventoryError, "unsupported-verse-label"):
            self.parse(page(verse("Synthetic injected words")))


class ImportAndFetchTests(unittest.TestCase):
    def test_browser_cross_page_fragments_merge_in_published_page_order(self):
        compact = browser_fixture()
        book = compact["books"][0]
        book["pages"][0]["chapters"].append({"label": "2", "verseOrder": ["1"]})
        book["pages"].insert(0, {"label": "2", "url": "https://bible.usccb.org/bible/genesis/2",
                                "chapters": [{"label": "2", "verseOrder": ["2", "3"]}]})
        imported = fetch.import_browser_inventory(compact)["books"]["GEN"]
        self.assertEqual(imported["chapterOrder"], ["1", "2"])
        self.assertEqual(imported["chapters"]["2"]["verseOrder"], ["1", "2", "3"])
        self.assertEqual(len(imported["chapters"]["2"]["sourcePages"]), 2)

    def test_browser_repeated_excerpts_do_not_erase_real_in_page_duplicates(self):
        compact = browser_fixture()
        book = compact["books"][0]
        book["pages"].append({"label": "2", "url": "https://bible.usccb.org/bible/genesis/2",
                              "chapters": [{"label": "1", "verseOrder": ["3", "4", "4", "5"]},
                                           {"label": "2", "maximum": 2}]})
        chapter = fetch.import_browser_inventory(compact)["books"]["GEN"]["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["1", "2", "3", "4", "4", "5"])
        self.assertEqual(chapter["duplicateVerses"], ["4"])

    def test_conflicting_presence_between_page_fragments_is_rejected(self):
        compact = browser_fixture()
        compact["books"][0]["pages"].append({"label": "2", "url": "https://bible.usccb.org/bible/genesis/2",
            "chapters": [{"label": "1", "verseOrder": ["4"], "omittedVerses": ["3"]},
                         {"label": "2", "maximum": 2}]})
        with self.assertRaisesRegex(fetch.InventoryError, "conflicting-page-verse-presence"):
            fetch.import_browser_inventory(compact)

    def test_browser_page_provenance_must_match_the_recorded_book_and_page(self):
        for target in ["https://bible.usccb.org/bible/genesis/2", "https://bible.usccb.org/bible/exodus/1"]:
            compact = browser_fixture()
            compact["books"][0]["pages"][0]["url"] = target
            with self.subTest(target=target), self.assertRaisesRegex(fetch.InventoryError, "browser-page-label-mismatch"):
                fetch.import_browser_inventory(compact)

    def test_same_page_presence_and_omission_cannot_both_claim_one_label(self):
        compact = browser_fixture()
        compact["books"][0]["pages"][0]["chapters"][0]["omittedVerses"] = ["2"]
        with self.assertRaisesRegex(fetch.InventoryError, "conflicting-verse-presence"):
            fetch.import_browser_inventory(compact)

    def test_browser_dense_transfer_expands_only_numeric_labels_and_records_hash_kind(self):
        inventory = fetch.import_browser_inventory(browser_fixture())
        self.assertFalse(inventory["complete"])
        self.assertEqual(inventory["books"]["GEN"]["chapters"]["1"]["verseOrder"], ["1", "2", "3"])
        self.assertEqual(inventory["source"]["hashKind"], "sha256-normalized-numeric-metadata-v1")
        fetch.validate_inventory(inventory, require_complete=False)
        with self.assertRaisesRegex(fetch.InventoryError, "incomplete-inventory"):
            fetch.validate_inventory(inventory)

    def test_browser_irregular_labels_and_omissions_survive_compact_transfer(self):
        compact = browser_fixture()
        compact["books"][0]["pages"][0]["chapters"] = [{"label": "1", "verseOrder": ["1", "3", "2", "2"], "omittedVerses": ["4"]}]
        inventory = fetch.import_browser_inventory(compact)
        chapter = inventory["books"]["GEN"]["chapters"]["1"]
        self.assertEqual(chapter["verseOrder"], ["1", "3", "2", "2"])
        self.assertEqual(chapter["omittedVerses"], ["4"])
        self.assertEqual(chapter["duplicateVerses"], ["2"])

    def test_browser_import_never_copies_unrecognized_fields_into_artifact(self):
        compact = browser_fixture()
        compact["rawHTML"] = "UNEXPECTED RAW PAYLOAD"
        compact["books"][0]["pages"][0]["chapters"][0]["text"] = "UNEXPECTED RAW PAYLOAD"
        self.assertNotIn("UNEXPECTED", json.dumps(fetch.import_browser_inventory(compact)))

    def test_browser_import_rejects_prose_in_reference_positions_and_arbitrary_urls(self):
        for value in ["Synthetic text", "0", "1<script>"]:
            compact = browser_fixture()
            compact["books"][0]["pages"][0]["chapters"] = [{"label": "1", "verseOrder": [value]}]
            with self.subTest(value=value), self.assertRaises(fetch.InventoryError):
                fetch.import_browser_inventory(compact)
        compact = browser_fixture()
        compact["books"][0]["pages"][0]["url"] = "https://untrusted.example/body"
        with self.assertRaises(fetch.InventoryError):
            fetch.import_browser_inventory(compact)

    def test_a_single_book_cannot_claim_complete_73_book_coverage(self):
        compact = browser_fixture()
        compact["books"][0]["pageOrder"] = ["1"]
        inventory = fetch.import_browser_inventory(compact)
        self.assertFalse(inventory["complete"])
        inventory["complete"] = True
        with self.assertRaisesRegex(fetch.InventoryError, "incomplete-book-set"):
            fetch.validate_inventory(inventory)

    def test_metadata_hash_ignores_dictionary_key_order(self):
        self.assertEqual(fetch.metadata_digest({"a": 1, "b": 2}), fetch.metadata_digest({"b": 2, "a": 1}))

    def test_403_stops_fetching_without_retry_or_body_persistence(self):
        class Response:
            status_code = 403
            headers = {"Content-Type": "text/html"}
            content = b"SYNTHETIC ACCESS CHECK BODY"
        fetcher = fetch.Fetcher(delay=0, retries=2)
        with patch.object(fetch.requests, "get", return_value=Response()) as request:
            with self.assertRaisesRegex(fetch.InventoryError, "fetch-http-403"):
                fetcher.get(fetch.INDEX_URL)
            with self.assertRaisesRegex(fetch.InventoryError, "fetch-stopped-after-access-block"):
                fetcher.get(fetch.INDEX_URL)
            self.assertEqual(request.call_count, 1)

    def test_blocked_index_writes_explicitly_incomplete_numeric_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "structure.json"
            with patch.object(fetch.Fetcher, "get", side_effect=fetch.InventoryError("fetch-http-403")):
                inventory = fetch.fetch_inventory(path, workers=2, delay=0.5, refresh=False)
            self.assertFalse(inventory["complete"])
            self.assertEqual(inventory["books"], {})
            self.assertEqual(json.loads(path.read_text())["errors"][0]["code"], "fetch-http-403")
            self.assertEqual(list(Path(directory).iterdir()), [path])


if __name__ == "__main__":
    unittest.main()
