#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Verify every Icon Composer color preserves the original rendered dark icon.

Requires macOS with Xcode's Icon Composer renderer. Run after build-app-icons.mjs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "Shared/Branding"


def verify(destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    developer = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
    renderer = developer.parent / "Applications/Icon Composer.app/Contents/Executables/ictool"
    if not renderer.is_file():
        raise RuntimeError("Select an Xcode installation that includes Icon Composer.")
    original = destination / "Original.icon"
    (original / "Assets").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(BRAND / "apple-original-icon.json", original / "icon.json")
    shutil.copyfile(BRAND / "cross-template.png", original / "Assets/Path 2.png")

    def render(package: Path, platform: str) -> bytes:
        target = destination / f"{package.stem}-{platform}-Dark.png"
        result = subprocess.run(
            [str(renderer), str(package), "--export-image", "--output-file", str(target),
             "--platform", platform, "--rendition", "Dark", "--width", "1024",
             "--height", "1024", "--scale", "1"],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(f"Could not render {package.name}:\n{result.stdout}\n{result.stderr}")
        return target.read_bytes()

    palette = json.loads((BRAND / "app-colors.json").read_text())
    for platform in ("iOS", "macOS"):
        expected = render(original, platform)
        for color in palette["colors"]:
            name = "Prosary" if color["id"] == palette["default"] else f"Prosary{color['id'].title()}"
            actual = render(ROOT / "iOS/Prosary" / f"{name}.icon", platform)
            if actual != expected:
                raise AssertionError(f"{name} {platform} Dark differs from the original dark icon; inspect {destination}")
            print(f"{name} ({platform}): original Dark preserved")
        print(f"Verified {len(palette['colors'])} {platform} dark icons; SHA-256 {hashlib.sha256(expected).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, help="Keep rendered evidence in this directory")
    args = parser.parse_args()
    if args.output_dir:
        verify(args.output_dir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix="prosary-dark-icons-") as directory:
            verify(Path(directory))
