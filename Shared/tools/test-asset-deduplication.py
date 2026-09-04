#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Verify that shipped prayer artwork has one native representation.

The built-in ``.prosaryprayer`` files are portable archives, so every image declared by a
manifest stays inside its pack.  Native apps load those entries directly and must not also ship
byte-identical copies in an asset catalog or resource directory.  This check also proves that
the generated pack copies in all three native projects still match ``Shared/dist`` exactly.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DIST = ROOT / "Shared" / "dist"
CANONICAL_IMAGES = ROOT / "Shared" / "Images"
NATIVE_PACK_DIRECTORIES = {
    "iOS": ROOT / "iOS" / "Prosary" / "PrayerPacks",
    "Android": ROOT / "Android" / "app" / "src" / "main" / "assets",
    "Windows": ROOT / "Windows" / "Prosary" / "PrayerPacks",
}
NATIVE_ARTWORK_DIRECTORIES = {
    "iOS": ROOT / "iOS" / "Prosary" / "Assets.xcassets",
    # Scan the whole resource tree so a duplicate cannot hide in drawable/, a density bucket,
    # or a future resource qualifier.
    "Android": ROOT / "Android" / "app" / "src" / "main" / "res",
    "Windows": ROOT / "Windows" / "Prosary" / "Assets" / "Images",
}
RASTER_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
UNPACKED_CANONICAL_IMAGES = {"cross_placeholder"}
NATIVE_FALLBACKS = {
    "iOS": ROOT
    / "iOS"
    / "Prosary"
    / "Assets.xcassets"
    / "cross_placeholder.imageset"
    / "cross_placeholder.svg",
    "Android": ROOT
    / "Android"
    / "app"
    / "src"
    / "main"
    / "res"
    / "drawable"
    / "cross_placeholder.xml",
    "Windows": ROOT / "Windows" / "Prosary" / "Assets" / "Images" / "cross_placeholder.png",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(problems: list[str], message: str) -> None:
    problems.append(message)


def main() -> int:
    problems: list[str] = []
    packed_image_digests: dict[str, list[str]] = {}
    packed_image_bytes = 0
    bundles = sorted(DIST.glob("*.prosaryprayer"))

    if not bundles:
        fail(problems, f"no built-in packs found in {DIST.relative_to(ROOT)}")

    expected_pack_names = {bundle.name for bundle in bundles}
    for platform, directory in NATIVE_PACK_DIRECTORIES.items():
        actual_pack_names = {pack.name for pack in directory.glob("*.prosaryprayer")}
        missing = sorted(expected_pack_names - actual_pack_names)
        extra = sorted(actual_pack_names - expected_pack_names)
        if missing:
            fail(problems, f"{platform} is missing built-in packs: {', '.join(missing)}")
        if extra:
            fail(problems, f"{platform} has stale/extra built-in packs: {', '.join(extra)}")

    for bundle in bundles:
        try:
            with zipfile.ZipFile(bundle) as archive:
                manifest = json.loads(archive.read("manifest.json"))
                bundle_id = manifest["id"]
                if bundle.stem != bundle_id:
                    fail(
                        problems,
                        f"{bundle.relative_to(ROOT)} is named for {bundle.stem!r}, "
                        f"but its manifest id is {bundle_id!r}",
                    )

                for image_key in manifest.get("images", []):
                    canonical_path = CANONICAL_IMAGES / f"{image_key}.jpg"
                    entry_name = f"images/{image_key}.jpg"
                    if not canonical_path.is_file():
                        fail(problems, f"missing canonical image {canonical_path.relative_to(ROOT)}")
                        continue
                    try:
                        packed_bytes = archive.read(entry_name)
                    except KeyError:
                        fail(problems, f"{bundle.relative_to(ROOT)} is missing {entry_name}")
                        continue
                    canonical_bytes = canonical_path.read_bytes()
                    if packed_bytes != canonical_bytes:
                        fail(
                            problems,
                            f"{bundle.relative_to(ROOT)}:{entry_name} differs from "
                            f"{canonical_path.relative_to(ROOT)}",
                        )
                    image_digest = digest(canonical_bytes)
                    packed_image_digests.setdefault(image_digest, []).append(image_key)
                    packed_image_bytes += len(canonical_bytes)
        except (OSError, zipfile.BadZipFile, json.JSONDecodeError, KeyError) as error:
            fail(problems, f"cannot inspect {bundle.relative_to(ROOT)}: {error}")
            continue

        canonical_pack_bytes = bundle.read_bytes()
        for platform, directory in NATIVE_PACK_DIRECTORIES.items():
            native_pack = directory / bundle.name
            if not native_pack.is_file():
                fail(problems, f"{platform} is missing {native_pack.relative_to(ROOT)}")
            elif native_pack.read_bytes() != canonical_pack_bytes:
                fail(
                    problems,
                    f"{native_pack.relative_to(ROOT)} differs from {bundle.relative_to(ROOT)}",
                )

    packed_image_keys = {
        image_key for image_keys in packed_image_digests.values() for image_key in image_keys
    }

    for platform, directory in NATIVE_ARTWORK_DIRECTORIES.items():
        if not directory.is_dir():
            fail(problems, f"missing {platform} resource directory {directory.relative_to(ROOT)}")
            continue
        for resource in directory.rglob("*"):
            if not resource.is_file() or resource.suffix.lower() not in RASTER_SUFFIXES:
                continue
            matching_keys = set(packed_image_digests.get(digest(resource.read_bytes()), []))
            if resource.stem in packed_image_keys:
                matching_keys.add(resource.stem)
            if matching_keys:
                keys = ", ".join(sorted(matching_keys))
                fail(
                    problems,
                    f"{resource.relative_to(ROOT)} duplicates packed artwork: {keys}",
                )

    canonical_image_keys = {
        image.stem
        for image in CANONICAL_IMAGES.iterdir()
        if image.is_file() and image.suffix.lower() in RASTER_SUFFIXES
    }
    orphaned_images = sorted(
        canonical_image_keys - packed_image_keys - UNPACKED_CANONICAL_IMAGES
    )
    if orphaned_images:
        fail(
            problems,
            "canonical artwork is neither packed nor an allowed native fallback: "
            + ", ".join(orphaned_images),
        )

    for platform, fallback in NATIVE_FALLBACKS.items():
        if not fallback.is_file():
            fail(problems, f"{platform} is missing its native artwork fallback: {fallback.relative_to(ROOT)}")

    if problems:
        for problem in problems:
            print(f"  {problem}")
        print(f"{len(problems)} asset layout problem(s)")
        return 1

    print(
        f"asset layout clean: {len(bundles)} portable packs are in sync; "
        f"{packed_image_bytes / 1_048_576:.2f} MiB of packed artwork has no loose native copy"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
