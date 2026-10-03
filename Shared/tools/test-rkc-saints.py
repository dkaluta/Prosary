#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.4,<1"]
# ///
"""Offline checks for the official Ukrainian event-source collector."""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("rkc_saints", Path(__file__).with_name("scrape-rkc-saints.py"))
scraper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scraper)
URL = "https://rkc.org.ua/events/svyatyj-franczysk-assizkyj-obovyazkovyj-spomyn/"
PROSE = "Франциск народився в Ассізі. Його молитва і любов до бідних служили Церкві. Її життя для нього було святим."


def card(url=URL, title="Святий Франциск Ассізький", date="Жов 04 2026"):
    return f'''<article class="mec-event-article mec-clear"><div class="mec-event-date">
    <span class="mec-start-date-label">{date}</span></div><h4 class="mec-event-title">
    <a data-event-id="123" href="{url}">{title}</a></h4></article>'''


def archive(body=None):
    return '''<html><h1>Святий дня</h1>''' + (body if body is not None else card()) + '''
    <script id="mec-frontend-script-js" src="https://rkc.org.ua/wp-content/litespeed/js/abcdef123.js?ver=abc123"></script>
    <script>jQuery("#mec_skin_mec1").mecListView({start_date:"2026-10-03",end_date:"2026-10-14",offset:"1",limit:"12",pagination:"loadmore",atts:"atts%5Bcategory%5D=153&atts%5Binstance_id%5D=mec1",current_month_divider:"202610",ajax_url:"https://rkc.org.ua/wp-admin/admin-ajax.php"})</script></html>'''


def article(body=PROSE, title="Святий Франциск Ассізький"):
    return f'''<html lang="uk"><nav>Unrelated menus</nav><h1 class="mec-single-title">{title}</h1>
    <div class="mec-single-event-description mec-events-content">{body}</div>
    <div class="mec-single-event-date">Date 04 Жовтня 2026</div>
    <script type="application/ld+json">{{"@type":"Event","name":"{title}","startDate":"2026-10-04","endDate":"2026-10-04"}}</script>
    <h2>Повне або часткове використання матеріалів дозволяється за умови посилання на https://rkc.org.ua/</h2></html>'''


class ExtractionTests(unittest.TestCase):
    def test_only_recognized_cards_are_discovered(self):
        rows = scraper.parse_cards('<nav><a href="https://rkc.org.ua/events/not-a-saint/">Menu</a></nav>' + card(), scraper.INDEX)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["sourceURL"], URL)
        self.assertEqual(rows[0]["sourceDateWording"], "Жов 04 2026")

    def test_source_occurrences_and_article_date_remain_distinct(self):
        instances = scraper.parse_cards(card(date="Жов 04 2027") + card(date="Жов 04 2028"), scraper.INDEX)
        result = scraper.parse_article(article(), URL, instances)
        self.assertEqual(len(result["indexOccurrences"]), 2)
        self.assertEqual(result["sourceEventDateEvidence"][0]["startDate"], "2026-10-04")
        self.assertEqual(result["indexOccurrences"][0]["sourceDateWording"], "Жов 04 2027")
        self.assertFalse(result["calendarAppointmentsChanged"])

    def test_body_characters_tails_and_order_are_preserved(self):
        body = 'Вступ.<p>Її <b>молитва</b> і любов.<script>ignored()</script> Добро.</p>Завершення.'
        result = scraper.parse_article(article(body), URL, [])
        self.assertEqual(result["paragraphs"], ["Вступ.", "Її молитва і любов. Добро.", "Завершення."])
        self.assertEqual(result["sourceTextSHA256"], scraper.sha("\n".join(result["paragraphs"])))
        self.assertNotIn("Unrelated menus", str(result["paragraphs"]))

    def test_author_reference_stays_source_evidence_without_automatic_attribution(self):
        result = scraper.parse_article(article('<p>' + PROSE + '</p><p>Джерело: <a href="https://credo.pro/example">CREDO</a></p>'), URL, [])
        self.assertEqual(result["creditCandidates"][0]["sourceWording"], "Джерело: CREDO")
        self.assertEqual(result["creditCandidates"][0]["reviewStatus"], "unreviewed")
        self.assertEqual(result["bodyLinks"][0]["sourceURL"], "https://credo.pro/example")

    def test_rights_notice_is_kept_separate_from_primary_body(self):
        result = scraper.parse_article(article(), URL, [])
        self.assertIn("посилання", result["policyEvidence"][0])
        self.assertNotIn("матеріалів", " ".join(result["paragraphs"]))

    def test_ordinary_period_is_excluded_from_biography_candidates(self):
        result = scraper.parse_article(article("Поточний літургійний тиждень Церкви.", "XXVI Тиждень звичайного періоду"), URL, [])
        self.assertEqual(result["genre"], "other-article-review-required")

    def test_actual_body_language_controls_language_code(self):
        result = scraper.parse_article(article("The saint lived in Assisi. His love and service were well known."), URL, [])
        self.assertIsNone(result["languageCode"])
        accepted = scraper.parse_article(article(), URL, [])
        self.assertEqual(accepted["languageCode"], "uk")

    def test_index_title_changes_are_flagged_without_overwriting_source(self):
        instances = scraper.parse_cards(card(title="Блаженний Карло Акутіс"), scraper.INDEX)
        result = scraper.parse_article(article(title="Святий Карло Акутіс"), URL, instances)
        self.assertEqual(result["title"], "Святий Карло Акутіс")
        self.assertIn("index-title-differs-from-article-title", result["sourceReviewIssues"])

    def test_ambiguous_article_template_fails(self):
        with self.assertRaises(ValueError):
            scraper.parse_article(article() + article(), URL, [])


class PaginationAndBoundaryTests(unittest.TestCase):
    def test_only_published_archive_options_are_used(self):
        result = scraper.pagination_options(archive())
        self.assertEqual(result["end_date"], "2026-10-14")
        self.assertEqual(result["offset"], "1")
        data = scraper.load_more_data(result).decode()
        self.assertIn("mec_start_date=2026-10-14", data)
        self.assertIn("action=mec_list_load_more", data)
        self.assertIn("apply_sf_date=0", data)

    def test_other_category_or_endpoint_fails(self):
        for source in [archive().replace("category%5D=153", "category%5D=999"),
                       archive().replace(scraper.AJAX, "https://evil.test/write"),
                       archive().replace("pagination:\"loadmore\"", "pagination:\"other\"")]:
            with self.assertRaises(ValueError):
                scraper.pagination_options(source)

    def test_empty_numeric_false_and_boolean_false_are_terminal(self):
        self.assertTrue(scraper.source_finished({"count": 0, "has_more_event": 1}))
        self.assertTrue(scraper.source_finished({"count": 3, "has_more_event": 0}))
        self.assertTrue(scraper.source_finished({"count": 3, "has_more_event": False}))
        self.assertFalse(scraper.source_finished({"count": 3, "has_more_event": 1}))

    def test_urls_cannot_escape_source_scope(self):
        for value in ["http://rkc.org.ua/events/a/", "https://rkc.org.ua.evil/events/a/", "https://user@rkc.org.ua/events/a/",
                      "https://rkc.org.ua:123/events/a/", "https://rkc.org.ua/wp-json/posts", "https://rkc.org.ua/?s=saint",
                      "https://rkc.org.ua/events/a/?secret=1", "https://rkc.org.ua/events/a/#anchor"]:
            self.assertIsNone(scraper.canonical_url(value), value)
        self.assertEqual(scraper.canonical_url(URL), URL)

    def test_post_cannot_be_an_unrelated_write_action(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(cache_dir=Path(directory), offline=True)
            client = scraper.Client(args)
            client.allowed.add(scraper.AJAX)
            with self.assertRaisesRegex(ValueError, "read-only"):
                client.fetch(scraper.AJAX, b"action=delete_post&apply_sf_date=0")


if __name__ == "__main__":
    unittest.main()
