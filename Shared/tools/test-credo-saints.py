#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.4,<1"]
# ///
"""Offline checks for the Ukrainian category-source scraper; no HTTP requests."""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

PATH = Path(__file__).with_name("scrape-credo-saints.py")
SPEC = importlib.util.spec_from_file_location("credo_saints", PATH)
scraper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scraper)

PROSE = "Римо-катол.: 1 жовтня (обов’язковий спомин)\nТереза від Дитяти Ісуса жила у Кармелі. Її молитва і любов служили Церкві."


def page(title="Свята Тереза від Дитяти Ісуса", prose=PROSE, next_page="https://credo.pro/saints/page/2"):
    return f'''<html lang="en"><nav><a href="https://credo.pro/2026/10/9">Navigation</a></nav>
    <h1 class="pagenam_custom_single">Свята та святі</h1><div id="content-block">
    <div class="row category_wrap"><div class="main-line-item">
    <a class="home-line-link" href="https://credo.pro/2026/09/69985"><div class="line_post_content_wrap">
    <h3>{title}</h3><p>{prose}</p><div><span class="numView">30 Вересня, 18:57</span>
    <span class="numView">12345</span><span class="tene">Свята та святі</span></div></div></a></div></div></div>
    <div id="wp_page_numbers"><a href="{next_page}">вперед</a></div>
    <div class="corit">Всі права на матеріали охороняються. Повне чи часткове використання матеріалів дозволяється лише з письмової згоди редакції.</div></html>'''


def full(body=PROSE):
    return f'''<html><h1 class="zagpagGeo main-type">Свята Тереза від Дитяти Ісуса</h1>
    <div class="single_cenpage"><span class="compost">30 Вересня 2026, 18:57</span>
    <span class="compost">12345</span><span class="author_single">Ірина Приклад</span></div>
    <div class="single-content">{body}<div class="author-wrap">Повна або часткова републікація тексту без письмової згоди редакції забороняється.</div></div>
    <aside>Recommended unrelated article</aside></html>'''


class ExtractionTests(unittest.TestCase):
    def test_card_scope_does_not_collect_navigation_news(self):
        result = scraper.parse_index(page(), scraper.INDEX)
        self.assertEqual(result["cardCount"], 1)
        self.assertEqual(result["articles"][0]["sourceURL"], "https://credo.pro/2026/09/69985")
        self.assertNotIn("Navigation", result["articles"][0]["sourceExcerpt"])

    def test_actual_ukrainian_prose_overrides_wrong_html_language_tag(self):
        result = scraper.parse_index(page(), scraper.INDEX)
        self.assertEqual(result["documentLanguageTag"], "en")
        self.assertEqual(result["articles"][0]["sourceLanguageEvidence"]["languageCode"], "uk")

    def test_russian_body_is_not_labelled_ukrainian(self):
        result = scraper.language_evidence("Святая Тереза жила в монастыре. Её жизнь была посвящена молитве и служению людям. Ещё она любила всех.")
        self.assertIsNone(result["languageCode"])
        self.assertGreater(sum(result["russianDistinctiveLetters"].values()), 0)

    def test_short_latin_body_not_inferred_from_ukrainian_title(self):
        result = scraper.parse_index(page(prose="English description of Saint Teresa."), scraper.INDEX)
        self.assertIsNone(result["articles"][0]["sourceLanguageEvidence"]["languageCode"])

    def test_truncation_and_source_hash_preserve_exact_source_characters(self):
        prose = PROSE + " Світло…"
        row = scraper.parse_index(page(prose=prose), scraper.INDEX)["articles"][0]
        self.assertEqual(row["sourceExcerpt"], prose)
        self.assertTrue(row["sourceTruncated"])
        self.assertEqual(row["sourceTextSHA256"], scraper.sha(prose))
        self.assertEqual(row["coverage"], "published-category-excerpt")

    def test_article_preserves_inline_tails_and_excluded_node_tails(self):
        body = '<p>Її <strong>молитва</strong> і любов.<script>untrusted()</script> Служіння Церкві.</p>'
        result = scraper.parse_article(full(body), "https://credo.pro/2026/09/69985")
        self.assertEqual(result["paragraphs"], ["Її молитва і любов. Служіння Церкві."])
        self.assertNotIn("untrusted", str(result["paragraphs"]))

    def test_article_keeps_loose_intro_and_loose_trailing_text(self):
        body = 'Вступ українською.<p>Основний опис.</p>Завершення українською.'
        result = scraper.parse_article(full(body), "https://credo.pro/2026/09/69985")
        self.assertEqual(result["paragraphs"], ["Вступ українською.", "Основний опис.", "Завершення українською."])

    def test_article_excludes_rights_notice_from_body_but_keeps_policy(self):
        result = scraper.parse_article(full(f"<p>{PROSE}</p>"), "https://credo.pro/2026/09/69985")
        self.assertNotIn("републікація", "\n".join(result["paragraphs"]))
        self.assertIn("републікація", " ".join(result["policyEvidence"]))
        self.assertEqual(result["creditCandidates"][0]["sourceWording"], "Ірина Приклад")

    def test_publication_date_is_separate_from_feast_date(self):
        row = scraper.parse_index(page(), scraper.INDEX)["articles"][0]
        self.assertEqual(row["publicationDateWording"], "30 Вересня, 18:57")
        self.assertEqual(row["publicationURLYearMonth"], "2026/09")
        self.assertEqual(row["literalDateEvidence"][0]["sourceWording"], "1 жовтня")
        self.assertIsNone(row["literalDateEvidence"][0]["explicitYear"])
        self.assertEqual(row["riteEvidence"][0]["rite"], "latin")

    def test_mixed_rite_description_does_not_transfer_dates(self):
        evidence = scraper.rite_evidence("Римо-катол.: 29 серпня (спомин)\nГреко-катол.: Усікновення голови св. Йоана Хрестителя")
        self.assertEqual([e["rite"] for e in evidence], ["latin", "byzantine"])
        self.assertEqual(evidence[1]["sourceWording"], "Греко-катол.: Усікновення голови св. Йоана Хрестителя")

    def test_news_reflection_is_not_a_biography(self):
        self.assertEqual(scraper.genre("Як свята Єлена знайшла Хрест Господній", "Історія давнього свята."), "other-article-review-required")
        self.assertEqual(scraper.genre("Свято Воздвиження Всечесного Хреста", "Історія свята."), "feast-description-candidate")

    def test_published_saint_abbreviations_and_explicit_memorial_titles_are_candidates(self):
        self.assertEqual(scraper.genre("Св. Єфрем Сирієць – Вчитель Церкви", "Життя святого."), "saint-biography-candidate")
        self.assertEqual(scraper.genre("Спомин св. Терези Бенедикти Хреста", "Життя святої."), "saint-biography-candidate")
        self.assertEqual(scraper.genre("Спомин святої Цецилії", "Життя святої."), "saint-biography-candidate")
        self.assertEqual(scraper.genre("Благовіщення Господнє", "Свято."), "feast-description-candidate")

    def test_future_or_reversed_year_range_is_flagged_without_correction(self):
        result = scraper.parse_article(full("<p>Її життя (1897-1873), інші роки 2026–2800.</p>"), "https://credo.pro/2026/09/69985")
        self.assertEqual([r["sourceWording"] for r in result["chronologyReview"]], ["1897-1873", "2026–2800"])
        self.assertIn("1897-1873", " ".join(result["paragraphs"]))

    def test_reviewed_historical_conflicts_do_not_edit_original_prose(self):
        prose = '<p>Вона стала покровителькою місій (1944).</p><p>Її проголошено Вчителем Церкви (1999).</p>'
        result = scraper.parse_article(full(prose), "https://credo.pro/2026/09/69985")
        self.assertEqual([r["primarySourceDate"] for r in result["sourceFactReview"]], ["1927-12-14", "1997-10-19"])
        self.assertIn("(1944)", " ".join(result["paragraphs"]))
        self.assertIn("(1999)", " ".join(result["paragraphs"]))
        self.assertEqual(result["sourceTextSHA256"], scraper.sha("\n".join(result["paragraphs"])))

    def test_missing_or_ambiguous_templates_fail(self):
        for source in ["<html>Challenge</html>", page().replace('class="pagenam_custom_single"', 'class="other"'),
                       page().replace('class="main-line-item"', 'class="other"')]:
            with self.assertRaises(ValueError):
                scraper.parse_index(source, scraper.INDEX)
        with self.assertRaises(ValueError):
            scraper.parse_article(full() + full(), "https://credo.pro/2026/09/69985")


class BoundaryTests(unittest.TestCase):
    def test_allowed_routes_are_strict(self):
        for url in ["https://credo.pro.evil/saints", "https://user@credo.pro/saints", "http://credo.pro/saints",
                    "https://credo.pro:444/saints", "https://credo.pro/wp-json/posts", "https://credo.pro/saints/feed",
                    "https://credo.pro/saints?foo=1", "https://credo.pro/saints#fragment", "https://credo.pro/2026/13/1",
                    "https://credo.pro/2026/09/69985/attachment"]:
            self.assertIsNone(scraper.canonical_url(url), url)
        self.assertEqual(scraper.canonical_url("/saints/page/2/"), "https://credo.pro/saints/page/2")

    def test_pagination_is_only_published_and_scoped(self):
        result = scraper.parse_index(page(next_page="https://credo.pro/saints/page/18"), scraper.INDEX)
        self.assertEqual(result["paginationURLs"], ["https://credo.pro/saints/page/18"])
        self.assertNotIn("https://credo.pro/saints/page/17", result["paginationURLs"])
        with self.assertRaises(ValueError):
            scraper.parse_index(page(next_page="https://evil.test/saints/page/2"), scraper.INDEX)

    def test_robots_rejects_challenge_and_missing_policy(self):
        for body, status, content_type in [(b"<html>Checking your browser</html>", 403, "text/html"),
                                          (b"<script>challenge()</script>", 200, "text/plain"),
                                          (b"Not Found", 404, "text/plain"),
                                          (b"Host: credo.pro", 200, "text/plain")]:
            with self.assertRaises(ValueError):
                scraper.robots_policy(body, status, content_type)

    def test_robots_wildcards_and_delay_are_honored(self):
        policy = scraper.robots_policy(b"User-agent: *\nDisallow: /wp-json/\nDisallow: */feed\nDisallow: *?s=\nCrawl-delay: 30\n", 200, "text/plain")
        self.assertFalse(policy.can_fetch("https://credo.pro/wp-json/posts", scraper.USER_AGENT))
        self.assertFalse(policy.can_fetch("https://credo.pro/saints/feed", scraper.USER_AGENT))
        self.assertFalse(policy.can_fetch("https://credo.pro/?s=Teresa", scraper.USER_AGENT))
        self.assertTrue(policy.can_fetch(scraper.INDEX, scraper.USER_AGENT))
        self.assertEqual(policy.crawl_delay(scraper.USER_AGENT), 30)

    def test_redirect_does_not_follow_external_hosts(self):
        import urllib.error
        with self.assertRaises(urllib.error.URLError):
            scraper.BoundedRedirect().redirect_request(None, None, 302, "Found", {}, "https://evil.test/saints")

    def test_incomplete_numbered_pagination_never_claims_completion(self):
        class FakeClient:
            def __init__(self, args):
                self.stats = {"networkRequests": 0, "cacheHits": 2, "downloadedBytes": 0}
                self.provenance = []
            def fetch(self, url, robots=False):
                if robots:
                    return {"body": b"<html>challenge</html>", "status": 403, "contentType": "text/html", "sourceHTMLSHA256": "fake"}
                source = page(next_page="https://credo.pro/saints/page/3" if url == scraper.INDEX else scraper.INDEX)
                return {"body": source.encode(), "status": 200}
            def establish_policy(self):
                return {"effectiveDelaySeconds": 30}
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(output=Path(directory) / "snapshot.json", max_pages=10, max_requests=10,
                                   max_bytes=1_000_000, max_response_bytes=100_000, sample_count=0)
            with patch.object(scraper, "Client", FakeClient):
                result, status = scraper.catalogue(args)
            self.assertEqual(status, 1)
            self.assertFalse(result["complete"])
            self.assertIn("numbered gap", result["errors"][0]["message"])
            self.assertEqual(len(result["articles"]), 1)
            self.assertEqual(len(result["articles"][0]["indexOccurrences"]), 2)


if __name__ == "__main__":
    unittest.main()
