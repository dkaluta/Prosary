#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Offline checks for Arabic source provenance and collection boundaries."""
import hashlib
import importlib.util
import json
import sys
import unittest
import contextlib
import io
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace

SPEC = importlib.util.spec_from_file_location("arabic_scraper", Path(__file__).with_name("scrape-evangelizo-arabic-saints.py"))
module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = module
SPEC.loader.exec_module(module)
SUBJECT = "11111111-2222-3333-4444-555555555555"
URL = module.BASE + "/AR/saints/" + SUBJECT
ARABIC = "وصف المصدر باللغة العربية مع كلمات إضافية للتحقق من حفظ النص كما ورد في المصدر."


def payload(body=None):
    return {"data": {"id": SUBJECT, "name": "عنوان المصدر باللغة العربية", "month": 10, "day": 1,
            "date_displayed": "١ أكتوبر", "bio": body or f"<p>{ARABIC}</p>",
            "bio_source": "Exact original source credit"}}


class ArabicScraperTests(unittest.TestCase):
    def parse(self, value, occurrences=None):
        raw = json.dumps(value, ensure_ascii=False).encode()
        return module.extract_biography(value, URL, raw, occurrences or [{"month": 10, "day": 1}])

    def test_collection_accepts_leap_day_and_rejects_invalid_dates(self):
        self.assertIsNotNone(module.canonical_url(module.collection_url(2, 29)))
        self.assertIsNone(module.canonical_url(module.collection_url(2, 30)))

    def test_only_reviewed_api_paths_and_query_shapes_are_allowed(self):
        for url in ("https://evil.example/AR/saints/" + SUBJECT,
                    module.BASE + "/FR/saints/" + SUBJECT,
                    module.BASE + "/AR/saints?query=secret",
                    module.BASE + "/AR/saints?day=1&month=10&day=2",
                    "https://user:pass@publication.evangelizo.ws/AR/saints/" + SUBJECT):
            with self.subTest(url=url):
                self.assertIsNone(module.canonical_url(url))

    def test_arabic_wording_and_exact_credit_survive(self):
        result = self.parse(payload())
        self.assertEqual(result["paragraphs"], [ARABIC])
        self.assertEqual(result["underlyingCredit"], "Exact original source credit")
        self.assertEqual(result["language"], "ar")
        self.assertEqual(result["review"]["issues"], [])
        self.assertEqual(result["review"]["redistribution"], "unapproved")

    def test_arabic_title_cannot_mask_english_prose(self):
        result = self.parse(payload("<p>This complete biography is English rather than Arabic.</p>"))
        self.assertIsNone(result["language"])
        self.assertIn("biography-language-needs-review", result["review"]["issues"])

    def test_subject_uuid_is_not_guessed_or_replaced(self):
        value = payload()
        value["data"]["id"] = "22222222-2222-3333-4444-555555555555"
        with self.assertRaises(ValueError):
            self.parse(value)

    def test_conflicting_source_date_is_flagged_without_changing_appointment(self):
        value = payload()
        value["data"]["day"] = 2
        result = self.parse(value)
        self.assertIn("subject-date-differs-from-collection", result["review"]["issues"])
        self.assertEqual(result["sourceMonthDay"]["day"], 2)
        self.assertEqual(result["collectionOccurrences"][0]["day"], 1)
        self.assertEqual(result["language"], "ar")

    def test_source_response_html_and_text_hashes_are_distinct_and_reproducible(self):
        value = payload()
        result = self.parse(value)
        self.assertEqual(result["sourceBiographyHTMLSHA256"], hashlib.sha256(value["data"]["bio"].encode()).hexdigest())
        self.assertEqual(result["sourceTextSHA256"], hashlib.sha256(ARABIC.encode()).hexdigest())
        self.assertEqual(result["sourceResponseSHA256"], hashlib.sha256(json.dumps(value, ensure_ascii=False).encode()).hexdigest())

    def test_script_and_image_alt_text_do_not_enter_source_prose(self):
        result = self.parse(payload(f"<p>{ARABIC}</p><script>hidden code</script><img alt='hidden image'>"))
        self.assertEqual(result["paragraphs"], [ARABIC])

    def test_invalid_delay_cannot_start_an_unpaced_or_stalled_crawl(self):
        for value in ("nan", "inf", "-inf", "0"):
            with self.subTest(value=value), patch.object(sys, "argv", ["scraper", "--delay=" + value]), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    module.main()
                self.assertEqual(error.exception.code, 2)

    def test_html_challenge_is_not_permissive_robots(self):
        for body, content_type in [(b"<html>Checking browser</html>", "text/html"),
                                   (b"<script>challenge()</script>", "text/plain"),
                                   (b"Service temporarily unavailable", "text/plain")]:
            with self.subTest(body=body), self.assertRaises(ValueError):
                module.source_robots(body, 200, content_type)
        self.assertTrue(module.source_robots(b"User-agent: *\nDisallow:\n", 200, "text/plain").can_fetch(URL, module.UA))
        self.assertTrue(module.source_robots(b"Not found", 404, "text/html").can_fetch(URL, module.UA))

    def test_published_crawl_delay_raises_all_throttle_minima(self):
        policy = module.source_robots(b"User-agent: *\nDisallow:\nCrawl-delay: 30\n", 200, "text/plain")
        delay = float(policy.crawl_delay(module.UA))
        throttle = object.__new__(module.AutoThrottle)
        throttle.mindelay, throttle.maxdelay = 2, 60
        slot, spider = SimpleNamespace(delay=2), SimpleNamespace()
        crawler = SimpleNamespace(engine=SimpleNamespace(downloader=SimpleNamespace(slots={"source": slot})),
                                  extensions=SimpleNamespace(middlewares=[throttle]))
        module.apply_source_delay(crawler, spider, delay)
        self.assertEqual((slot.delay, spider.download_delay, throttle.mindelay), (30, 30, 30))


if __name__ == "__main__":
    unittest.main(verbosity=2)
