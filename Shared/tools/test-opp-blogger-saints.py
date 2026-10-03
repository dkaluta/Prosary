#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Offline checks of the historical archive's feed scope and source adapter."""
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from xml.sax.saxutils import escape

SPEC = importlib.util.spec_from_file_location("opp_blogger_scraper", Path(__file__).with_name("scrape-opp-blogger-saints.py"))
scraper = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scraper
SPEC.loader.exec_module(scraper)
PROSE = ("Si Santo Halimbawa ay naging isang banal na pari sa kanyang bayan. "
         "Noong bata siya ay mahal niya ang Diyos at ang mga taong walang tahanan. "
         "Dahil sa kanyang pananampalataya naging mabuti ang kanyang gawain para sa lahat ng tao.")


def feed(*, content=None, next_url=None, total=1, start=1, identity=None, source_url=None):
    if content is None:
        content = ("<p>OKTUBRE 1</p><p>A. KUWENTO NG BUHAY</p><p>" + PROSE + "</p>"
                   "<p>B. HAMON SA BUHAY</p><p>Pagninilay ng may-akda.</p>"
                   "<p>K. KATAGA NG BUHAY</p><p>Salmo 1:1</p>"
                   "<p>(from: Isang Sulyap sa mga Santo, by Fr. RMarcos)</p>")
    identity = identity or f"tag:blogger.com,1999:blog-{scraper.BLOG_ID}.post-123"
    source_url = source_url or scraper.BASE + "2021/09/saint-example.html"
    next_tag = '<link rel="next" href="' + escape(next_url) + '"/>' if next_url else ""
    return (f'<feed xmlns="{scraper.NS["a"]}" xmlns:o="{scraper.NS["o"]}">'
        f'<o:totalResults>{total}</o:totalResults><o:startIndex>{start}</o:startIndex>'
        '<o:itemsPerPage>25</o:itemsPerPage>' + next_tag + '<entry><id>' + identity + '</id>'
        '<published>2021-09-29T12:00:00Z</published><updated>2022-03-12T12:00:00Z</updated>'
        '<title>SAINTS OF OCTOBER: SANTO HALIMBAWA</title><category term="SAINT"/>'
        '<author><name>Published feed author</name></author><content type="html">' + escape(content) + '</content>'
        '<link rel="alternate" type="text/html" href="' + source_url + '"/></entry></feed>').encode()


class BloggerSaintTests(unittest.TestCase):
    def record(self, **kwargs):
        page = scraper.parse_feed(feed(**kwargs))
        return scraper.extract_entry(page["entries"][0], scraper.FEED, "a" * 64)

    def test_safety_rejects_search_guessed_filters_other_blogs_and_credentials(self):
        for url in (scraper.BASE + "search/label/SAINT", scraper.FEED + "/-/SAINT",
                scraper.FEED + "?max-results=500", scraper.BLOGGER + "feeds/1/posts/default?start-index=26&max-results=25",
                scraper.BLOGGER + f"feeds/{scraper.BLOG_ID}/posts/default?start-index=26&max-results=25&alt=json",
                scraper.BLOGGER + f"feeds/{scraper.BLOG_ID}/posts/default?start-index=26&start-index=51&max-results=25",
                "https://user:secret@ourparishpriest.blogspot.com/2021/01/saint.html",
                scraper.BASE + "2021/01/image.jpg", scraper.BASE + "2021/01/saint.html#fragment"):
            self.assertFalse(scraper.safe_url(url), url)

    def test_actual_published_feed_and_next_cursor_are_allowed(self):
        url = scraper.BLOGGER + f"feeds/{scraper.BLOG_ID}/posts/default?start-index=26&max-results=25"
        self.assertTrue(scraper.safe_url(scraper.FEED))
        self.assertTrue(scraper.safe_url(url))
        self.assertTrue(scraper.safe_url(scraper.BASE + "2014/11/meet-saints-san-juan-bosco_21.html"))
        page = scraper.parse_feed(feed(next_url=url, total=26))
        self.assertEqual(page["nextURL"], url)
        self.assertEqual(page["total"], 26)
        self.assertEqual(page["start"], 1)

    def test_html_and_unknown_next_urls_cannot_be_reported_as_complete_feed(self):
        for value in (b"<html>Just a moment</html>", feed(next_url="https://evil.example/feed")):
            with self.assertRaises(ValueError):
                scraper.parse_feed(value)

    def test_missing_counters_do_not_support_completeness(self):
        for value in (feed(total=0), feed(start=0), feed().replace(b"<o:itemsPerPage>25</o:itemsPerPage>", b"")):
            with self.assertRaises(ValueError):
                scraper.parse_feed(value)

    def test_preserves_original_article_body_dates_and_real_blogger_identity(self):
        record = self.record()
        self.assertEqual(record["recordId"], "opp-blogger:123")
        self.assertEqual(record["bloggerPostID"], "123")
        self.assertNotIn("wordPressPostID", record)
        self.assertEqual(record["sourceURL"], scraper.BASE + "2021/09/saint-example.html")
        self.assertEqual(record["sourcePublishedAt"], "2021-09-29T12:00:00Z")
        self.assertEqual([(x["month"], x["day"]) for x in record["sourceFeastLabels"]], [(10, 1)])
        self.assertEqual(record["sections"]["biography"], [PROSE])
        self.assertEqual(record["sections"]["reflection"], ["Pagninilay ng may-akda."])
        self.assertTrue(record["sourceCapture"]["sourceIsHistoricalArchive"])
        self.assertFalse(record["nativeImportAllowed"])

    def test_exact_credits_full_source_hash_and_feed_author_remain_distinct(self):
        record = self.record()
        self.assertEqual(record["literalCredits"], ["(from: Isang Sulyap sa mga Santo, by Fr. RMarcos)"])
        self.assertEqual(record["sourceAtomAuthor"], "Published feed author")
        self.assertEqual(record["sourceHTMLSHA256"], scraper.SOURCE.sha256(record["sourceHTML"]))
        self.assertEqual(record["sourceTextSHA256"], scraper.SOURCE.sha256("\n".join(record["sourceParagraphs"])))

    def test_english_article_with_saint_category_and_filipino_title_is_not_tagalog(self):
        record = self.record(content="<p>OKTUBRE 1</p><p>A. KUWENTO NG BUHAY</p><p>" + "He was a priest who lived in this town and cared for the people. " * 10 + "</p>")
        self.assertIsNone(record["languageCode"])
        self.assertIn("biography-not-demonstrably-Tagalog", record["review"]["reasons"])

    def test_redirect_stub_or_unmarked_reflection_is_preserved_without_biography_claim(self):
        record = self.record(content="<p>Matutunghayan sa ating bagong website.</p><p>" + PROSE + "</p>")
        self.assertEqual(record["sections"]["biography"], [])
        self.assertIn("no-explicit-biography-section", record["review"]["reasons"])
        self.assertIn(PROSE, record["sourceParagraphs"])

    def test_body_tails_and_inline_markup_are_preserved(self):
        record = self.record(content="<p>OKTUBRE 1</p><p>A. KUWENTO NG BUHAY</p><p>" + PROSE + " <b>Huling salita</b> at kasunod na buntot.</p><p>B. HAMON SA BUHAY</p>")
        self.assertTrue(record["sections"]["biography"][0].endswith("Huling salita at kasunod na buntot."))

    def test_word_formatting_newlines_do_not_hide_explicit_biography_or_reflection_headers(self):
        raw = "<div>OKTUBRE 1</div><div><span>A.\nKUWENTO NG BUHAY</span></div><div>" + PROSE + "</div>"
        raw += "<div><b>B. HAMON SA\nBUHAY</b></div><div>Pagninilay ng may-akda.</div>"
        raw += "<div>K. KATAGA NG\nBUHAY</div><div>Salmo 1:1</div>"
        record = self.record(content=raw)
        self.assertEqual(record["sourceHTML"], raw)
        self.assertEqual(record["sections"]["biography"], [PROSE])
        self.assertEqual(record["sections"]["reflection"], ["Pagninilay ng may-akda."])
        self.assertEqual(record["classification"], "Tagalog-biography-review-candidate")

    def test_real_br_stays_boundary_while_physical_formatting_wraps_normalize(self):
        raw = "<div>A.\nKUWENTO NG BUHAY</div><p>unang\nlinya<br/>ikalawang\nlinya</p>"
        blocks = scraper.SOURCE.source_blocks(scraper.logical_html(raw))
        self.assertEqual(blocks, ["A. KUWENTO NG BUHAY", "unang linya", "ikalawang linya"])

    def test_split_line_pio_death_error_is_detected_and_original_words_remain(self):
        raw = "<p>SETYEMBRE 23</p><p>A. KUWENTO NG BUHAY</p><p>" + PROSE + " Namatay si Padre\nPio noong 1969.</p>"
        page = scraper.parse_feed(feed(content=raw).replace(b"SANTO HALIMBAWA", b"PADRE PIO"))
        record = scraper.extract_entry(page["entries"][0], scraper.FEED, "a" * 64)
        self.assertIn("source-factual-error-confirmed-by-Holy-See", record["review"]["reasons"])
        self.assertEqual(record["sourceHTML"], raw)
        self.assertIn("Pio noong 1969", " ".join(record["sections"]["biography"]))

    def test_explicit_continuation_is_an_excerpt_and_notice_is_not_biography_prose(self):
        raw = "<p>OKTUBRE 1</p><p>A. KUWENTO NG BUHAY</p><p>" + PROSE + "</p>"
        raw += "<p>tunghayan ang kabuuan dito sa ating bagong website: https://www.ourparishpriest.com/</p>"
        record = self.record(content=raw)
        self.assertEqual(record["classification"], "Tagalog-biography-excerpt-review-candidate")
        self.assertEqual(record["sections"]["biography"], [PROSE])
        self.assertTrue(record["sourceCompletenessEvidence"]["biographyContinuesOnNewSite"])
        self.assertIn("tunghayan ang kabuuan", record["sections"]["migrationNotice"][0])
        self.assertEqual(record["sourceHTML"], raw)

    def test_narrative_use_of_kabuuan_with_unrelated_link_does_not_invent_truncation(self):
        raw = "<p>OKTUBRE 1</p><p>A. KUWENTO NG BUHAY</p><p>" + PROSE + "</p>"
        raw += '<p>Sa kabuuan ng kanyang buhay ay nanalangin siya.</p><p>B. HAMON SA BUHAY</p>'
        raw += '<p><a href="https://www.ourparishpriest.com/">Ibang artikulo</a></p>'
        record = self.record(content=raw)
        self.assertFalse(record["sourceCompletenessEvidence"]["biographyContinuesOnNewSite"])
        self.assertEqual(record["classification"], "Tagalog-biography-review-candidate")

    def test_independently_verified_capuchin_conflict_is_held_without_prose_correction(self):
        record = self.record()
        record["recordId"] = "opp-blogger:5538193347137277050"
        original = "Buhay pa si San Francisco ay nagkaroon na ng tatlong sangay, kasama ang Franciscan Capuchins."
        record["sections"]["biography"].append(original)
        scraper.annotate_known_source_conflicts(record)
        self.assertEqual(record["classification"], "quarantined-source")
        self.assertEqual(record["sections"]["biography"][-1], original)
        self.assertEqual(record["review"]["findings"][-1]["type"], "source-franciscan-branches-chronology-error")

    def test_wrong_archive_id_missing_full_content_and_foreign_article_are_rejected(self):
        for value in (feed(identity="tag:blogger.com,1999:blog-1.post-123"),
                feed().replace(b'<content type="html">', b'<summary type="html">').replace(b'</content>', b'</summary>'),
                feed(source_url="https://evil.example/2021/01/saint.html")):
            with self.assertRaises(ValueError):
                scraper.extract_entry(scraper.parse_feed(value)["entries"][0], scraper.FEED, "a" * 64)

    def test_robots_disallows_label_search_but_permits_published_feed(self):
        policy = scraper.SOURCE.source_robots(b"User-agent: *\nDisallow: /search\nAllow: /\n", 200, "text/plain")
        self.assertFalse(policy.can_fetch(scraper.BASE + "search/label/SAINT", scraper.USER_AGENT))
        self.assertTrue(policy.can_fetch(scraper.FEED, scraper.USER_AGENT))


if __name__ == "__main__":
    unittest.main()
