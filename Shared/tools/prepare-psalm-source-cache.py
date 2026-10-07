#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Prepare only the hash-pinned witnesses needed by Psalm regression audits.

No source profile, generated reading, inventory or native asset is modified.
Downloads require --fetch; existing cache bytes are always checksum-verified.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError

TOOLS = Path(__file__).resolve().parent
MAX_FETCH_ATTEMPTS = 3


def source_bytes_with_retry(builder, source, *, fetch=False):
    """Retry bounded transport failures; leave source verification and cache bytes alone."""
    for attempt in range(1, MAX_FETCH_ATTEMPTS + 1):
        try:
            return builder.source_bytes(source, fetch=fetch)
        except (URLError, TimeoutError) as error:
            if (not fetch or attempt == MAX_FETCH_ATTEMPTS
                    or isinstance(error, HTTPError) and not (error.code == 429 or 500 <= error.code < 600)):
                raise
            print(f"{source['id']}: {type(error).__name__}; retrying source fetch "
                  f"({attempt + 1}/{MAX_FETCH_ATTEMPTS}).", file=sys.stderr, flush=True)
            time.sleep(attempt)  # Short 1s/2s backoff; the builder retains its request timeout.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
    sources = {source["id"]: source for source in lock["sources"]}
    review = json.loads((TOOLS / "martini-daily-psalm-reviews.json").read_text())
    required = {"engDRA", "grcbrent", "peshitta-eu-2020-psa-118"}
    for witness in review["sources"]:
        source = sources.get(witness["id"])
        if source is None or source["sha256"] != witness["sha256"]:
            raise ValueError("Reviewed Italian Psalm source differs from the canonical source lock")
        required.add(witness["id"])
    if len(required) != 153:
        raise ValueError("Psalm regression source inventory changed; review the cache prerequisites")
    spec = importlib.util.spec_from_file_location("psalm_cache_builder", TOOLS / "build-reading-texts.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    for identifier in sorted(required):
        source_bytes_with_retry(builder, sources[identifier], fetch=args.fetch)
    print(f"Verified {len(required)} pinned Psalm regression source payloads.")


if __name__ == "__main__":
    main()
