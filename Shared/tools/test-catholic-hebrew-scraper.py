#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Offline checks for Hebrew source extraction and bounded link discovery."""
from __future__ import annotations

import hashlib
import importlib.util
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

SCRIPT = Path(__file__).with_name("scrape-catholic-hebrew-saints.py")
SPEC = importlib.util.spec_from_file_location("catholic_hebrew_scraper", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
scraper = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scraper
SPEC.loader.exec_module(scraper)

INDEX_URL = "https://www.catholic.co.il/?cat=faith&m=Feasts&view=category&id=35&lang=he"
ARTICLE_URL = "https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=7038&lang=he"


def article(title="חג הקדוש לדוגמה – ב-27 בספטמבר", intro="תיאור מקור בעברית, עם סימני פיסוק.",
            body='<p>פסקה ראשונה עם <a href="https://example.org/reference">קישור מקור</a> ומילים בעברית.</p>'
                 '<p>פסקה שנייה: תֵּאוּר, ׳, ״, “ציטוט” — בדיוק ככתוב.<br>שורה נוספת של טקסט מקור.</p>'):
    # Deliberately incorrect HTML language and unrelated Hebrew sidebar exercise the site traps.
    return f'''<!doctype html><html lang="ru"><body>
      <nav><a href="/?id=99&view=article&cat=news">חדשות</a></nav>
      <a href="/?id=2590&cat=faith&view=article&lang=he&m=Feasts"><img src="/img/he_il.gif" alt="עברית"></a>
      <a href="/?id=2590&cat=faith&view=article&lang=en&m=Feasts"><img src="/img/en.gif" alt="English"></a>
      <div id="main_content"><div class="col-md-7 mapWrapper"><div>
        <h1>{title}</h1><br><div style="margin-bottom:10px;font-weight:bold">{intro}</div>{body}
      </div></div><div class="col-md-2 mapWrapper"><p>הטקסט הצדדי אינו הביוגרפיה</p></div></div>
      <footer>© 2020 Saint James Vicariate for Hebrew Speaking Catholics in Israel</footer>
      </body></html>'''.encode("utf-8")


def category(cards="", next_page=1):
    return f'''<div id="main_content"><div class="col-md-8 mapWrapper">
      <div><h1>חגים</h1>{cards}</div><div><a
      href="index.php?lang=he&cat=faith&view=category&id=35&m=Feasts&page={next_page}">→</a>
      </div></div></div>'''.encode("utf-8")


class CatholicHebrewScraperTests(unittest.TestCase):
    def parse(self, document, url=ARTICLE_URL):
        return scraper.extract_article(document, url, request_url=url, discovered_index_url=INDEX_URL)

    def test_link_scope_rejects_external_hosts_credentials_and_unrelated_sections(self):
        for url in ("https://example.org/?id=7038&view=article&cat=faith&m=Feasts",
                    "https://www.catholic.co.il.evil.example/?id=7038&view=article&cat=faith&m=Feasts",
                    "https://user:password@www.catholic.co.il/?id=7038&view=article&cat=faith&m=Feasts",
                    "javascript:alert(1)", "https://www.catholic.co.il/?id=7038&view=article&cat=news",
                    "https://www.catholic.co.il/?id=33&view=category&cat=faith&m=Feasts"):
            with self.subTest(url=url):
                self.assertIsNone(scraper.canonical_url(url))

    def test_index_follows_main_articles_and_actual_next_link_without_menu_or_sidebar(self):
        document = '''<html lang="ru"><body>
          <nav><a href="/?id=999&view=article&cat=faith&m=Feasts">תפריט</a></nav>
          <div id="main_content"><div class="col-md-8 mapWrapper">
            <div><h1>חגים</h1><a href="/?cat=faith&view=article&id=7038&m=Feasts">
              <h3>חג הקדוש לדוגמה – ב-27 בספטמבר</h3><div class="cat_intro">מבוא קצר בעברית</div></a></div>
            <div><a href="index.php?lang=he&cat=faith&view=category&id=35&m=Feasts&page=1">→</a>עמוד: 1</div>
          </div><div class="col-md-2"><a href="/?id=777&view=article&cat=faith&m=Feasts">צד</a></div></div>
          <footer>© 2020 Saint James Vicariate</footer></body></html>'''
        result = scraper.extract_index(document, INDEX_URL)
        self.assertEqual(len(result["articles"]), 1)
        self.assertIn("7038", result["articles"][0]["url"])
        self.assertIn("lang=he", result["articles"][0]["url"])
        self.assertEqual(len(result["pagination"]), 1)
        self.assertIn("page=1", result["pagination"][0])

    def populated_spider_with_next_request(self):
        spider = scraper.HebrewSaintsSpider(SimpleNamespace(max_pages=100, max_articles=100))
        spider.scheduled_pages.add(INDEX_URL)
        cards = '<a href="/?cat=faith&view=article&id=7038&m=Feasts"><h3>חג קדוש</h3></a>'
        request = scraper.scrapy.Request(INDEX_URL)
        response = scraper.scrapy.http.HtmlResponse(INDEX_URL, request=request,
                                                    body=category(cards), encoding="utf-8")
        requests = list(spider.parse_index(response))
        next_request = next(item for item in requests if "view=category" in item.url)
        return spider, next_request

    def test_published_empty_tail_ends_the_list_despite_another_next_arrow(self):
        spider, request = self.populated_spider_with_next_request()
        response = scraper.scrapy.http.HtmlResponse(request.url, request=request,
                                                    body=category(next_page=2), encoding="utf-8")
        self.assertEqual(list(spider.parse_index(response)), [])
        self.assertEqual(spider.errors, [])
        self.assertTrue(spider.natural_end)
        self.assertTrue(spider.index_pages[request.url]["terminalEmptyPage"])

    def test_empty_first_page_cannot_report_a_complete_crawl(self):
        spider = scraper.HebrewSaintsSpider(SimpleNamespace(max_pages=100, max_articles=100))
        request = scraper.scrapy.Request(INDEX_URL)
        response = scraper.scrapy.http.HtmlResponse(INDEX_URL, request=request,
                                                    body=category(), encoding="utf-8")
        self.assertEqual(list(spider.parse_index(response)), [])
        self.assertTrue(spider.errors)
        self.assertFalse(spider.natural_end)

    def test_unrecognized_article_cards_cannot_be_mistaken_for_the_empty_tail(self):
        spider, request = self.populated_spider_with_next_request()
        cards = '<a href="https://example.org/unrecognized"><h3>תיאור מקור</h3></a>'
        response = scraper.scrapy.http.HtmlResponse(request.url, request=request,
                                                    body=category(cards, next_page=2), encoding="utf-8")
        self.assertEqual(list(spider.parse_index(response)), [])
        self.assertTrue(spider.errors)
        self.assertFalse(spider.natural_end)

    def test_article_keeps_source_hebrew_and_excludes_sidebar(self):
        result = self.parse(article())
        self.assertIsNone(result["rejectionReason"])
        self.assertEqual(result["reviewStatus"], "required")
        self.assertEqual(result["introduction"], "תיאור מקור בעברית, עם סימני פיסוק.")
        prose = "\n".join(result["paragraphs"])
        self.assertIn("קישור מקור", prose)
        self.assertIn("תֵּאוּר, ׳, ״, “ציטוט” — בדיוק ככתוב.", prose)
        self.assertIn("שורה נוספת", prose)
        self.assertNotIn("הטקסט הצדדי", prose)
        self.assertNotIn("Saint James Vicariate", prose)

    def test_source_digest_and_requested_final_identity_are_preserved(self):
        document = article()
        result = scraper.extract_article(document, ARTICLE_URL, request_url=ARTICLE_URL.replace("7038", "2590"),
                                         discovered_index_url=INDEX_URL)
        self.assertEqual(str(result["articleId"]), "7038")
        self.assertEqual(result["sourceHTMLSHA256"], hashlib.sha256(document).hexdigest())
        self.assertIn("7038", result["sourceURL"])
        self.assertIn("2590", result["requestURL"])
        self.assertEqual(result["discoveredIndexURL"], INDEX_URL)

    def test_crawler_preserves_initial_request_and_published_flag_journey(self):
        initial_url = ARTICLE_URL.replace("7038", "2494")
        followed_url = ARTICLE_URL.replace("7038", "2590")
        request = scraper.scrapy.Request(ARTICLE_URL, meta={"originalRequestURL": followed_url})
        response = scraper.scrapy.http.HtmlResponse(ARTICLE_URL, request=request,
                                                    body=article(), encoding="utf-8")
        spider = scraper.HebrewSaintsSpider(SimpleNamespace(max_articles=100))
        self.assertEqual(list(spider.parse_article(response, INDEX_URL, {"url": initial_url},
                                                  [initial_url, followed_url])), [])
        record = next(iter(spider.article_records.values()))
        self.assertEqual(record["requestURL"], followed_url)
        self.assertEqual(record["sourceURL"], ARTICLE_URL)
        self.assertEqual(record["publishedLinkChain"], [initial_url, followed_url])

    def test_hebrew_menu_and_query_do_not_disguise_an_english_article(self):
        result = self.parse(article("Feast of an example saint - September 27", "English introduction",
                                   "<p>This is an English biography, with no Hebrew source prose.</p>"))
        self.assertIsNotNone(result["rejectionReason"])
        self.assertIn("2590", result["hebrewFlagURL"])

    def test_hebrew_heading_does_not_disguise_an_english_body(self):
        result = self.parse(article(intro="This introduction is English rather than Hebrew.",
                                   body="<p>This entire long biography is English and must never become Hebrew content merely because the heading or menu uses Hebrew characters.</p>"))
        self.assertIsNotNone(result["rejectionReason"])

    def test_long_hebrew_introduction_does_not_disguise_an_english_body(self):
        result = self.parse(article(intro="תיאור מקור בעברית עם הקדמה ארוכה לצורך בדיקה. " * 30,
                                   body="<p>This biography is English despite the lengthy Hebrew introduction.</p>"))
        self.assertGreater(result["languageEvidence"]["hebrewLetterShare"], 0.70)
        self.assertEqual(result["bodyLanguageEvidence"]["hebrewLetters"], 0)
        self.assertIsNotNone(result["rejectionReason"])
        rejected = scraper.quarantine_record(result)
        self.assertEqual(rejected["introduction"], result["introduction"])
        self.assertEqual(rejected["paragraphs"], [])
        self.assertLessEqual(len(rejected["bodyEvidence"]), 240)

    def test_short_hebrew_body_is_preserved_without_following_a_wrong_language_flag(self):
        result = self.parse(article(intro="הקדמה ארוכה בעברית עם תיאור מקור שנשמר בדיוק לצורך סקירה.",
                                   body="<p>תיאור קצר במקור בעברית.</p>"))
        self.assertLess(result["bodyLanguageEvidence"]["hebrewLetters"], 40)
        self.assertIsNone(result["rejectionReason"])
        self.assertEqual(result["contentShape"], "short-body")
        self.assertEqual(result["paragraphs"], ["תיאור קצר במקור בעברית."])

    def test_introduction_only_hebrew_source_is_kept_as_a_review_candidate(self):
        introduction = "תיאור המקור כולו נמצא בהקדמה בעברית, עם טקסט נוסף שנשמר בדיוק לצורך סקירה."
        result = self.parse(article(intro=introduction, body=""))
        self.assertIsNone(result["rejectionReason"])
        self.assertEqual(result["contentShape"], "introduction-only")
        self.assertEqual(result["introduction"], introduction)
        self.assertEqual(result["paragraphs"], [])
        self.assertEqual(result["reviewStatus"], "required")

    def test_foreign_introduction_only_source_is_rejected_despite_hebrew_heading(self):
        result = self.parse(article(intro="The source article consists of this English introduction.", body=""))
        self.assertIsNotNone(result["rejectionReason"])

    def test_mixed_source_retains_full_foreign_quotations_and_separate_hebrew_evidence(self):
        hebrew = "פסקת מקור בעברית עם תיאור ארוך שנשמר בדיוק לצורך סקירה ולבדיקת המקור."
        foreign = "An original foreign quotation retained as source evidence. " * 10
        result = self.parse(article(body=f"<p>{hebrew}</p><p>{foreign}</p>"))
        self.assertIsNotNone(result["rejectionReason"])
        rejected = scraper.quarantine_record(result)
        self.assertEqual(rejected["sourceLanguageShape"], "mixed-language")
        self.assertEqual(rejected["fullSourceProse"]["paragraphs"], result["paragraphs"])
        self.assertEqual(rejected["paragraphs"], [hebrew])
        self.assertIsNone(rejected["language"])
        self.assertEqual(rejected["reviewStatus"], "required")

    def test_invalid_utf8_fails_without_replacing_source_characters(self):
        with self.assertRaises(UnicodeDecodeError):
            self.parse(article() + b"\xff")

    def test_script_style_and_image_alt_text_do_not_enter_the_article(self):
        body = '<p>פסקת מקור ארוכה בעברית, עם טקסט נוסף כדי לבדוק את החילוץ המדויק.</p>' \
               '<script>טקסט סקריפט</script><style>טקסט סגנון</style>' \
               '<img src="/example.jpg" alt="טקסט תמונה"><p>המשך פסקת המקור בעברית.</p>'
        result = self.parse(article(body=body))
        self.assertIsNone(result["rejectionReason"])
        prose = "\n".join(result["paragraphs"])
        for excluded in ("טקסט סקריפט", "טקסט סגנון", "טקסט תמונה"):
            self.assertNotIn(excluded, prose)

    def test_bare_prose_between_blocks_is_kept_in_source_order(self):
        body = 'משפט ראשון במקור עם <b>מילים מודגשות</b> וטקסט נוסף בעברית.' \
               '<br>משפט שני במקור בעברית.' \
               '<p>פסקה שלישית במקור עם מילים נוספות בעברית.</p>' \
               'משפט רביעי במקור אחרי הפסקה.'
        result = self.parse(article(body=body))
        self.assertIsNone(result["rejectionReason"])
        prose = "\n".join(result["paragraphs"])
        markers = ("משפט ראשון", "מילים מודגשות", "משפט שני", "פסקה שלישית", "משפט רביעי")
        positions = [prose.index(marker) for marker in markers]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn(result["title"], prose)
        self.assertNotIn(result["introduction"], prose)

    def test_missing_article_container_does_not_extract_the_menu_as_a_biography(self):
        result = self.parse('<html><body><nav>קדוש תיאור מקור בעברית</nav><h1>חג קדוש</h1></body></html>')
        self.assertIsNotNone(result["rejectionReason"])

    def test_prayer_and_general_feast_remain_candidates_requiring_review(self):
        for title in ("תפילה עבור הבריאה – ב-1 בספטמבר", "חג לידת מרים – ב-8 בספטמבר"):
            with self.subTest(title=title):
                result = self.parse(article(title))
                self.assertIsNone(result["rejectionReason"])
                self.assertEqual(result["reviewStatus"], "required")
                self.assertNotEqual(result["classification"], "saint-biography-candidate")
                self.assertNotIn("calendarDate", result)
                self.assertNotIn("approvedIdentity", result)

    def test_intro_credit_survives_as_exact_source_text(self):
        for introduction in ("האחות גבריאלה שלחה לנו תיאור מקור קצר בעברית לצורך סקירה.",
                             "לוציה כותבת לנו תיאור מקור קצר בעברית לצורך סקירה.",
                             "האחות גבריאלה כתבה לנו תיאור מקור קצר בעברית לצורך סקירה."):
            with self.subTest(introduction=introduction):
                result = self.parse(article(intro=introduction))
                self.assertEqual(result["introduction"], introduction)
                self.assertTrue(result["credits"])
                self.assertEqual(result["credits"][0]["text"], introduction)


if __name__ == "__main__":
    unittest.main(verbosity=2)
