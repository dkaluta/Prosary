#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Bounded transport retries never bypass pinned-source integrity checks."""
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, call, patch
from urllib.error import HTTPError, URLError

TOOLS = Path(__file__).resolve().parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


cache_prep = module("psalm_source_cache_test_subject", "prepare-psalm-source-cache.py")
builder = module("psalm_source_cache_test_builder", "build-reading-texts.py")


class PsalmSourceCacheTests(unittest.TestCase):
    def setUp(self):
        self.source = {"id": "pinned-fixture", "url": "https://example.invalid/pinned",
                       "format": "vpl", "cache": "pinned.txt",
                       "sha256": hashlib.sha256(b"pinned payload\n").hexdigest()}
        self.sleep = patch.object(cache_prep.time, "sleep").start()
        self.addCleanup(patch.stopall)
        patch.object(cache_prep, "print").start()

    def subject(self, failures):
        read = Mock(side_effect=failures)
        return SimpleNamespace(source_bytes=read), read

    def test_timeout_recovers_without_changing_the_source_request(self):
        subject, read = self.subject([TimeoutError("transient"), b"pinned payload\n"])
        self.assertEqual(cache_prep.source_bytes_with_retry(subject, self.source, fetch=True), b"pinned payload\n")
        self.assertEqual(read.call_args_list, [call(self.source, fetch=True)] * 2)
        self.sleep.assert_called_once_with(1)

    def test_url_transport_error_recovers(self):
        subject, read = self.subject([URLError(TimeoutError("transient")), b"pinned payload\n"])
        self.assertEqual(cache_prep.source_bytes_with_retry(subject, self.source, fetch=True), b"pinned payload\n")
        self.assertEqual(read.call_count, 2)

    def test_only_throttling_and_server_http_errors_are_retried(self):
        for status in (429, 500, 503, 599):
            with self.subTest(status=status):
                error = HTTPError(self.source["url"], status, "temporary", None, None)
                subject, read = self.subject([error, b"pinned payload\n"])
                self.assertEqual(cache_prep.source_bytes_with_retry(subject, self.source, fetch=True), b"pinned payload\n")
                self.assertEqual(read.call_count, 2)

    def test_not_found_and_other_client_http_errors_fail_immediately(self):
        for status in (400, 401, 403, 404, 408, 410, 422):
            with self.subTest(status=status):
                error = HTTPError(self.source["url"], status, "permanent", None, None)
                subject, read = self.subject([error])
                with self.assertRaises(HTTPError) as caught:
                    cache_prep.source_bytes_with_retry(subject, self.source, fetch=True)
                self.assertIs(caught.exception, error)
                self.assertEqual(read.call_count, 1)
        self.sleep.assert_not_called()

    def test_checksum_mismatch_fails_immediately(self):
        error = ValueError("Source checksum changed")
        subject, read = self.subject([error])
        with self.assertRaises(ValueError) as caught:
            cache_prep.source_bytes_with_retry(subject, self.source, fetch=True)
        self.assertIs(caught.exception, error)
        read.assert_called_once_with(self.source, fetch=True)
        self.sleep.assert_not_called()

    def test_persistent_timeouts_stop_after_three_attempts(self):
        error = TimeoutError("still unavailable")
        subject, read = self.subject([error] * 3)
        with self.assertRaises(TimeoutError) as caught:
            cache_prep.source_bytes_with_retry(subject, self.source, fetch=True)
        self.assertIs(caught.exception, error)
        self.assertEqual(read.call_count, 3)
        self.assertEqual(self.sleep.call_args_list, [call(1), call(2)])

    def test_offline_verification_does_not_retry_a_fetch(self):
        subject, read = self.subject([URLError("unavailable")])
        with self.assertRaises(URLError):
            cache_prep.source_bytes_with_retry(subject, self.source, fetch=False)
        read.assert_called_once_with(self.source, fetch=False)
        self.sleep.assert_not_called()

    def test_actual_builder_checks_recovered_payload_against_the_pin(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(builder, "CACHE", Path(directory)), \
                patch.object(builder.urllib.request, "urlopen", side_effect=[TimeoutError("transient"), io.BytesIO(b"pinned payload\n")]) as fetch:
            self.assertEqual(cache_prep.source_bytes_with_retry(builder, self.source, fetch=True), b"pinned payload\n")
            self.assertEqual(fetch.call_count, 2)
            self.assertEqual((Path(directory) / self.source["cache"]).read_bytes(), b"pinned payload\n")

    def test_actual_builder_keeps_mismatched_cached_bytes_and_never_refetches_them(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(builder, "CACHE", Path(directory)), \
                patch.object(builder.urllib.request, "urlopen") as fetch:
            path = Path(directory) / self.source["cache"]
            path.write_bytes(b"mismatched existing bytes")
            with self.assertRaisesRegex(ValueError, "Source checksum changed"):
                cache_prep.source_bytes_with_retry(builder, self.source, fetch=True)
            self.assertEqual(path.read_bytes(), b"mismatched existing bytes")
            fetch.assert_not_called()
            self.sleep.assert_not_called()


if __name__ == "__main__":
    unittest.main()
