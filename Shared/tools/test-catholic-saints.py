#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3", "lingua-language-detector>=2,<3"]
# ///
"""Offline regressions for multilingual source preservation and bounded discovery."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import sys
import unittest
from pathlib import Path

from scrapy import Request
from scrapy.http import HtmlResponse

SCRIPT = Path(__file__).with_name("scrape-catholic-saints.py")
SPEC = importlib.util.spec_from_file_location("catholic_saints_scraper", SCRIPT)
SCRAPER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SCRAPER
SPEC.loader.exec_module(SCRAPER)

PROSE = {
    "en": "Her life was dedicated to helping poor families. She cared for sick children and encouraged her friends to serve their neighbours with patience and compassion.",
    "fr": "Elle a consacré sa vie à aider les familles pauvres. Elle prenait soin des enfants malades et encourageait ses amis à servir leurs voisins avec patience et compassion.",
    "it": "Ha dedicato la sua vita ad aiutare le famiglie povere. Si prendeva cura dei bambini malati e incoraggiava i suoi amici a servire i loro vicini con pazienza e compassione.",
    "ru": "Она посвятила свою жизнь помощи бедным семьям. Она заботилась о больных детях и призывала своих друзей служить ближним с терпением и состраданием.",
}
TITLES = {"en": "Feast of Saint Example – October 1", "fr": "Fête de sainte Exemple – 1er octobre",
          "it": "Festa di Santa Esempio – 1 Ottobre", "ru": "Праздник святой Пример – 1 октября"}


def article(language="en", intro=None, body=None, title=None):
    return f'''<html lang="ru"><body><nav>תפריט בעברית English menu Français Italiano</nav>
      <a href="/?cat=faith&m=Feasts&view=article&id=3887&lang=fr"><img src="/img/fr_fr.gif" alt="Français"></a>
      <div id="main_content"><div class="col-md-7"><div>
      <h1>{title or TITLES[language]}</h1><br>
      <div style="font-weight:bold">{PROSE[language] if intro is None else intro}</div>
      {f'<p>{PROSE[language]}</p>' if body is None else body}
      </div></div><div class="col-md-2"><p>Related article should never be collected.</p></div></div>
      <footer>© 2020 Saint James Vicariate for Hebrew Speaking Catholics in Israel</footer></body></html>'''.encode()


def index(language="en", page=0, empty=False, malformed=False):
    card = "" if empty else f'''<a href="/?cat=faith&m=Feasts&view=article&id=2494{'' if not malformed else '&cat=news'}">
      <h3>{TITLES[language]}</h3><div class="cat_intro">{PROSE[language]}</div></a>'''
    region = {"en": "en-GB", "fr": "fr-FR", "it": "it-IT", "ru": "ru-RU"}[language]
    return f'''<html><div id="main_content"><div class="col-md-8"><div>
      <h1>{SCRAPER.EDITIONS[language]['heading']}</h1>{card}</div>
      <a href="index.php?cat=faith&m=Feasts&view=category&id=35&lang={region}&page={page+1}">next</a>
      </div></div></html>'''.encode()


class CatholicSaintsTests(unittest.TestCase):
    def parse(self, document, language="en", entry=None):
        return SCRAPER.extract_article(document, f"{SCRAPER.BASE}?cat=faith&m=Feasts&view=article&id=2494&lang={language}",
                                       language, index_entry=entry)

    def test_published_regional_aliases_normalize(self):
        for language, region in [("en", "en-GB"), ("fr", "fr-FR"), ("it", "it-IT"), ("ru", "ru-RU")]:
            url = SCRAPER.canonical_url(f"index.php?cat=faith&m=Feasts&view=category&id=35&lang={region}&page=1")
            self.assertEqual(SCRAPER.url_language(url), language)
            self.assertIn("page=1", url)

    def test_missing_language_inherits_source_edition(self):
        url = SCRAPER.canonical_url("/?cat=faith&m=Feasts&view=article&id=3887", SCRAPER.index_url("fr"))
        self.assertEqual(SCRAPER.url_language(url), "fr")

    def test_off_scope_and_duplicate_queries_are_rejected(self):
        for url in ["https://evil.example/?cat=faith&m=Feasts&view=article&id=2494&lang=en",
                    "https://user:pass@www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=2494&lang=en",
                    "/?cat=faith&m=Feasts&view=article&id=2494&lang=en&lang=fr",
                    "/?cat=faith&m=Feasts&view=category&id=33&lang=en"]:
            self.assertIsNone(SCRAPER.canonical_url(url))

    def test_all_four_actual_languages_override_wrong_html_attribute(self):
        for language in PROSE:
            with self.subTest(language=language):
                result = self.parse(article(language), language)
                self.assertIsNone(result["rejectionReason"])
                self.assertEqual(result["language"], language)
                self.assertEqual(result["htmlLanguageAttribute"], "ru")
                self.assertEqual(result["paragraphs"], [PROSE[language]])

    def test_english_fallback_cannot_pass_french_italian_or_russian(self):
        for language in ["fr", "it", "ru"]:
            result = self.parse(article(language, intro=PROSE["en"], body=f'<p>{PROSE["en"]}</p>'), language)
            self.assertEqual(result["rejectionReason"], "source-language-mismatch-or-uncertain")
            self.assertEqual(result["paragraphs"], [PROSE["en"]])
            self.assertIsNone(result["language"])

    def test_long_correct_intro_never_masks_foreign_body(self):
        result = self.parse(article("fr", intro=PROSE["fr"] * 8, body=f'<p>{PROSE["en"]}</p>'), "fr")
        self.assertIsNone(result["language"])
        self.assertEqual(result["bodyLanguageEvidence"]["detectedLanguage"], "en")

    def test_flag_picture_does_not_authorize_a_different_edition(self):
        document = article("fr").replace(b"id=3887&lang=fr", b"id=2494&lang=en")
        result = self.parse(document, "fr")
        self.assertIn("lang=en", result["languageFlagURL"])
        self.assertFalse(result["languageFlagMatchesRequestedEdition"])
        self.assertIn("published-language-flag-targets-another-edition", {issue["code"] for issue in result["review"]["issues"]})

    def test_intro_only_biography_is_preserved(self):
        result = self.parse(article("it", body=""), "it")
        self.assertIsNone(result["rejectionReason"])
        self.assertEqual(result["contentShape"], "introduction-only")
        self.assertEqual(result["introduction"], PROSE["it"])

    def test_foreign_intro_only_remains_complete_source_evidence(self):
        result = self.parse(article("fr", intro=PROSE["en"] * 10, body=""), "fr")
        self.assertIsNotNone(result["rejectionReason"])
        self.assertEqual(result["introduction"], PROSE["en"] * 10)

    def test_mixed_latin_source_is_never_truncated(self):
        latin = "Stabat mater dolorosa iuxta crucem lacrimosa dum pendebat filius. " * 20
        result = self.parse(article("fr", body=f"<p>{latin}</p><p>{PROSE['fr']}</p>"), "fr")
        self.assertEqual(result["paragraphs"][0], latin.strip())
        self.assertEqual(result["paragraphs"][1], PROSE["fr"])
        self.assertEqual(result["reviewStatus"], "required")

    def test_source_hash_and_bare_prose_are_preserved(self):
        document = article(body=f"Before the image.<img alt='not prose'>After the image.<p>{PROSE['en']}</p>Trailing source text.")
        result = self.parse(document)
        self.assertEqual(result["sourceHTMLSHA256"], hashlib.sha256(document).hexdigest())
        self.assertIn("Before the image.After the image.", result["paragraphs"])
        self.assertIn("Trailing source text.", result["paragraphs"])
        self.assertNotIn("Related article", " ".join(result["paragraphs"]))

    def test_literal_credit_is_evidence_not_translator_assignment(self):
        intro = "Sister Gabriella sent us this biography. " + PROSE["en"]
        result = self.parse(article(intro=intro))
        self.assertEqual(result["credits"][0]["text"], intro)
        self.assertEqual(result["credits"][0]["kind"], "credit-or-reference")
        self.assertNotIn("translator", result)

    def test_actual_mother_teresa_credit_prefix_is_not_missed(self):
        # Exact credit prefix from the public EN 2489 article; remaining fixture is synthetic.
        intro = "Lucia of the Jerusalem community wrote to us " + PROSE["en"]
        result = self.parse(article(intro=intro))
        self.assertEqual(result["credits"][0]["text"], intro)
        self.assertEqual(result["credits"][0]["kind"], "credit-or-reference")

    def test_other_language_credit_verbs_retain_literal_evidence(self):
        for language, phrase in [("fr", "Lucia nous a écrit. "), ("it", "Lucia ci ha scritto. "),
                                 ("ru", "Люсия прислала нам. ")]:
            intro = phrase + PROSE[language]
            result = self.parse(article(language, intro=intro), language)
            self.assertEqual(result["credits"][0]["text"], intro)

    def test_title_mismatch_is_a_review_issue(self):
        result = self.parse(article(), entry={"title": "Different source caption"})
        self.assertFalse(result["review"]["automatedChecks"]["indexTitleMatches"])
        self.assertEqual(result["review"]["issues"][0]["code"], "index-article-title-mismatch")

    def test_five_digit_year_typo_is_preserved_and_confirmed_only_for_actual_russian_source(self):
        body = PROSE["ru"] + " Тереза скончалась 30 сентября 19897 года."
        document = article("ru", body=f"<p>{body}</p>")
        result = SCRAPER.extract_article(document, SCRAPER.BASE + "?cat=faith&m=Feasts&view=article&id=3889&lang=ru", "ru")
        codes = {issue["code"] for issue in result["review"]["issues"]}
        self.assertIn("implausible-year-literal-or-identifier-needs-context", codes)
        self.assertIn("confirmed-source-death-year-discrepancy", codes)
        self.assertIn("19897", result["paragraphs"][0])
        no_typo = SCRAPER.extract_article(document.replace(b"19897", b"1897"),
                                          SCRAPER.BASE + "?cat=faith&m=Feasts&view=article&id=3889&lang=ru", "ru")
        self.assertNotIn("confirmed-source-death-year-discrepancy", {issue["code"] for issue in no_typo["review"]["issues"]})

    def test_long_identifier_is_review_candidate_not_an_automatic_error(self):
        result = self.parse(article(body=f"<p>{PROSE['en']} Meeting identifier 123456789.</p>"))
        self.assertIsNone(result["rejectionReason"])
        self.assertEqual(result["longNumericLiteralReviewCandidates"][0]["literal"], "123456789")

    def test_actual_pagination_and_source_captions_remain(self):
        result = SCRAPER.extract_index(index("fr"), SCRAPER.index_url("fr"), "fr")
        self.assertEqual(result["articles"][0]["title"], TITLES["fr"])
        self.assertEqual(result["articleIDs"], ["2494"])
        self.assertIn("lang=fr-FR", list(result["publishedPagination"].values())[0])
        self.assertEqual(SCRAPER.url_language(result["pagination"][0]), "fr")

    def spider(self):
        args = argparse.Namespace(languages=["en"], max_pages=100, max_articles=2000, output_dir=Path("/tmp"),
                                  delay=2, cache_expiry=86400, max_requests=3000, max_bytes=100*1024*1024)
        spider = SCRAPER.SaintsSpider(args)
        spider.save_all = lambda reason: None
        return spider

    def test_empty_tail_requires_published_populated_parent(self):
        spider = self.spider()
        root = SCRAPER.index_url("en")
        next_page = root + "&page=1"
        spider.states["en"]["indexPages"][root] = {"articleCount": 20, "pagination": [next_page]}
        request = Request(next_page, meta={"populatedParentURL": root})
        response = HtmlResponse(next_page, body=index(page=1, empty=True), request=request, encoding="utf-8")
        self.assertEqual(list(spider.parse_index(response, "en")), [])
        self.assertTrue(spider.states["en"]["naturalEnd"])
        self.assertTrue(spider.states["en"]["indexPages"][next_page]["terminalEmptyPage"])

    def test_empty_root_and_malformed_cards_are_errors(self):
        for document in [index(empty=True), index(malformed=True)]:
            spider = self.spider()
            root = SCRAPER.index_url("en")
            response = HtmlResponse(root, body=document, request=Request(root), encoding="utf-8")
            self.assertEqual(list(spider.parse_index(response, "en")), [])
            self.assertTrue(spider.states["en"]["errors"])
            self.assertFalse(spider.states["en"]["naturalEnd"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
