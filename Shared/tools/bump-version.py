#!/usr/bin/env python3
"""Increments (or syncs) the app version across all three platforms in one shot.

Usage:
  bump-version.py --check            report every declared version and any mismatches
  bump-version.py patch|minor|major  increment from the canonical version (Android versionName)
  bump-version.py X.Y.Z              set an explicit version
  ... [--dry-run]                    show what would change without writing

What it writes:
  Android  app/build.gradle.kts      versionName = X.Y.Z ; versionCode += 1
  iOS      project.pbxproj           MARKETING_VERSION = X.Y.Z (app target only — matched by
                                     the old value, so the test target's 1.0 is untouched);
                                     CURRENT_PROJECT_VERSION = major*10000 + minor*100 + patch
                                     (monotonic for semver order; 0.2.0 -> 200 matches history)
  Windows  Package.appxmanifest      Version="X.Y.Z.0"

Setting the version it already has is a pure sync: stragglers (like a stale appxmanifest) are
aligned but versionCode/CURRENT_PROJECT_VERSION are left alone, so re-running is harmless.

Release model (see the repo memory / ARCHITECTURE): work on feature branches; a merge to main
that finishes a major project bumps the minor; small fix releases bump the patch.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
GRADLE = ROOT / "Android/app/build.gradle.kts"
PBXPROJ = ROOT / "iOS/Prosary.xcodeproj/project.pbxproj"
APPXMANIFEST = ROOT / "Windows/Prosary/Package.appxmanifest"


def read_versions():
    gradle = GRADLE.read_text()
    name = re.search(r'versionName = "(\d+\.\d+\.\d+)"', gradle).group(1)
    code = int(re.search(r"versionCode = (\d+)", gradle).group(1))
    pbx = PBXPROJ.read_text()
    marketing = sorted(set(re.findall(r"MARKETING_VERSION = (\d+\.\d+\.\d+);", pbx)))
    build_nums = sorted(set(int(n) for n in re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", pbx)))
    manifest = APPXMANIFEST.read_text()
    win = re.search(r'\bVersion="(\d+\.\d+\.\d+)\.\d+"', manifest).group(1)
    return name, code, marketing, build_nums, win


def project_build_number(version: str) -> int:
    major, minor, patch = (int(p) for p in version.split("."))
    return major * 10000 + minor * 100 + patch


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(args) != 1:
        print(__doc__)
        return 2

    name, code, marketing, build_nums, win = read_versions()
    if args[0] == "--check":
        print(f"Android : versionName {name}  versionCode {code}")
        print(f"iOS     : MARKETING_VERSION {marketing}  CURRENT_PROJECT_VERSION {build_nums}")
        print(f"Windows : appxmanifest {win}.0")
        ok = name in marketing and win == name
        print("in sync" if ok else f"MISMATCH — canonical (Android) is {name}")
        return 0 if ok else 1

    major, minor, patch = (int(p) for p in name.split("."))
    if args[0] == "major":
        new = f"{major + 1}.0.0"
    elif args[0] == "minor":
        new = f"{major}.{minor + 1}.0"
    elif args[0] == "patch":
        new = f"{major}.{minor}.{patch + 1}"
    elif re.fullmatch(r"\d+\.\d+\.\d+", args[0]):
        new = args[0]
    else:
        print(__doc__)
        return 2

    sync_only = new == name
    prefix = "[dry-run] " if dry else ""

    gradle = GRADLE.read_text()
    gradle = gradle.replace(f'versionName = "{name}"', f'versionName = "{new}"')
    if not sync_only:
        gradle = gradle.replace(f"versionCode = {code}", f"versionCode = {code + 1}")
        print(f"{prefix}Android : {name} -> {new}, versionCode {code} -> {code + 1}")
    else:
        print(f"{prefix}Android : {new} (unchanged)")

    pbx = PBXPROJ.read_text()
    pbx = pbx.replace(f"MARKETING_VERSION = {name};", f"MARKETING_VERSION = {new};")
    if not sync_only:
        old_bn = project_build_number(name)
        pbx = pbx.replace(f"CURRENT_PROJECT_VERSION = {old_bn};",
                          f"CURRENT_PROJECT_VERSION = {project_build_number(new)};")
        print(f"{prefix}iOS     : {name} -> {new}, build {old_bn} -> {project_build_number(new)}")
    else:
        print(f"{prefix}iOS     : {new} (marketing synced if it lagged)")

    manifest = APPXMANIFEST.read_text()
    manifest = re.sub(r'\bVersion="\d+\.\d+\.\d+\.\d+"', f'Version="{new}.0"', manifest, count=1)
    print(f"{prefix}Windows : {win}.0 -> {new}.0")

    if not dry:
        GRADLE.write_text(gradle)
        PBXPROJ.write_text(pbx)
        APPXMANIFEST.write_text(manifest)

    return 0


if __name__ == "__main__":
    sys.exit(main())
