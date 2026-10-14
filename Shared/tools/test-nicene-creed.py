#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pin supplied Nicene wording and its separate catalog/data contract across native ports.

Runtime source policy and exact clause rendering are covered by the native
Nicene tests; this independent source check ensures those renderers do not rewrite the
canonical prayers, change the existing Creed, invent reading aids, or ship stale packs.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import runpy
import unicodedata
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "Shared"
FIXTURE = json.loads((SHARED / "tools/fixtures/nicene-creed.json").read_text())
PARSE_SWIFT = runpy.run_path(str(SHARED / "tools/audit-prayer-coverage.py"))["swift_prayers"]
PACK_PATHS = (
    ("iOS", ROOT / "iOS/Prosary/PrayerPacks/rosary.prosaryprayer"),
    ("Android", ROOT / "Android/app/src/main/assets/rosary.prosaryprayer"),
    ("Windows", ROOT / "Windows/Prosary/PrayerPacks/rosary.prosaryprayer"),
)


def content(language: str) -> dict:
    return json.loads((SHARED / f"content/rosary/content/{language}.json").read_text())


def without_hebrew_marks(text: str) -> str:
    return "".join(char for char in text
                   if not ("\u0591" <= char <= "\u05bd" or char in "\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7"))


def native_body(platform: str, table: str) -> str:
    if platform == "iOS":
        return PARSE_SWIFT(ROOT / f"iOS/Prosary/Mocks/Content/PrayerTranslations+{table}.swift")["symbolumApostolorum"]
    if platform == "Android":
        path = ROOT / f"Android/app/src/main/java/com/dkaluta/prosary/content/PrayerTranslations{table}.kt"
        prefix = r"PrayerKey\.SymbolumApostolorum\s+to\s+"
    else:
        path = ROOT / f"Windows/Prosary/Localization/PrayerTranslations.{table}.cs"
        prefix = r"\[PrayerKey\.SymbolumApostolorum\]\s*=\s*"
    strings = r'(?:"(?:[^"\\]|\\.)*"\s*(?:\+\s*)?)+'
    match = re.search(prefix + "(" + strings + ")", path.read_text())
    if not match:
        raise AssertionError(f"Cannot read {path.relative_to(ROOT)} Creed source")
    return "".join(json.loads(raw) for raw in re.findall(r'"(?:[^"\\]|\\.)*"', match[1]))


class NiceneCreedSourceTests(unittest.TestCase):
    def test_vicariate_relays_pointed_print_without_editorial_vocalization(self):
        hebrew = content("he")
        body = hebrew["prayers"]["symbolumNicaenum"]
        self.assertEqual(body, FIXTURE["hebrewVicariate"]["text"])
        self.assertEqual(body, unicodedata.normalize("NFC", body))
        self.assertIn("הנובע מהאב ומהבן.", without_hebrew_marks(body))
        self.assertNotIn("[", body)
        self.assertNotIn("]", body)
        for supplied in ("מוּלָד", "עַצְמוֹ עֶצֶם הָאָב", "אֲשֶׁר נוֹלַד", "וְלֹא יִהְיֶה קֵץ",
                         "כְּלָאָב וְכַלְבֵּן", "וּלְמַעַן יִשְׁעֵנוּ", "הַמְחַיֶּה, הַנּוֹבֵעַ"):
            self.assertIn(unicodedata.normalize("NFC", supplied), body)
        source = FIXTURE["hebrewVicariate"]
        self.assertEqual(source["sourceFile"], "IMG_5448.jpeg")
        self.assertEqual(source["sourcePage"], 6)
        self.assertEqual(source["sourceSHA256"], "0753c52ca77cad106feec019884775f064a1fbb75b814edfeaa8d87cb97eade7")
        original = source["initialUnpointedTranscription"]
        self.assertIn("ישעינו", original)
        corrected = original.replace("ישעינו", "ישענו").replace("המחיה הנובע", "המחיה, הנובע")
        self.assertEqual(without_hebrew_marks(body).split(), corrected.split(),
                         "Only the two source-verified transcription corrections change the initial supplied words")
        self.assertEqual(hebrew["$prayerTraditionByKey"]["symbolumNicaenum"], "vicariate")
        self.assertEqual(hebrew["$prayerTraditionByKey"]["symbolumNicaenumTitle"], "vicariate")
        self.assertNotIn("symbolumNicaenum", hebrew.get("transliterations", {}))
        self.assertTrue(hebrew.get("$sources", {}).get("symbolumNicaenum"), "Credit the user-supplied Vicariate print")

    def test_existing_nicene_sources_are_copied_without_normalization(self):
        for language, record in FIXTURE["existingNiceneSources"].items():
            with self.subTest(language=language):
                localized = content(language)
                self.assertEqual(localized["prayers"]["symbolumNicaenum"], record["text"])
                if "readingAid" in record:
                    self.assertEqual(localized["transliterations"]["symbolumNicaenum"], record["readingAid"])
                    self.assertEqual(localized["prayers"]["symbolumApostolorum"], record["text"])
                    self.assertEqual(localized["transliterations"]["symbolumApostolorum"], record["readingAid"])
                else:
                    self.assertNotIn("symbolumNicaenum", localized.get("transliterations", {}))
        for platform in ("iOS", "Android", "Windows"):
            for language, table in (("he-x-gamliel", "HebrewGamaliel"), ("el", "Greek")):
                with self.subTest(platform=platform, language=language):
                    self.assertEqual(native_body(platform, table), FIXTURE["existingNiceneSources"][language]["text"])

    def test_existing_vicariate_apostles_creed_remains_distinct(self):
        for platform in ("iOS", "Android", "Windows"):
            with self.subTest(platform=platform):
                self.assertEqual(native_body(platform, "Hebrew"), FIXTURE["existingApostlesHebrew"])
        self.assertNotEqual(FIXTURE["existingApostlesHebrew"], content("he")["prayers"]["symbolumNicaenum"])
        rosary = json.loads((SHARED / "content/rosary/devotion.json").read_text())
        mercy = json.loads((SHARED / "content/divineMercyChaplet/devotion.json").read_text())
        self.assertTrue(any(step.get("bodyKey") == "symbolumApostolorum" for step in rosary["opening"]))
        self.assertTrue(any(step.get("bodyKey") == "symbolumApostolorum" for step in mercy["opening"]))

    def test_latin_fallback_relays_verified_ancient_source(self):
        latin = content("la")
        self.assertEqual(latin["prayers"]["symbolumNicaenum"], FIXTURE["latin"]["text"])
        self.assertEqual(latin["$sources"]["symbolumNicaenum"], FIXTURE["latin"]["source"])
        self.assertIn("qui ex Patre Filioque procedit.", latin["prayers"]["symbolumNicaenum"])
        self.assertIn("Et exspecto resurrectionem mortuorum", latin["prayers"]["symbolumNicaenum"])

    def test_separate_basic_catalog_identity_has_three_way_parity(self):
        catalogs = (
            (ROOT / "iOS/Prosary/Support/BasicPrayerCatalog.swift", r'BasicPrayer\(id:\s*"([^"]+)"'),
            (ROOT / "Android/app/src/main/java/com/dkaluta/prosary/models/BasicPrayerCatalog.kt", r'BasicPrayer\(\s*"([^"]+)"'),
            (ROOT / "Windows/Prosary/Models/BasicPrayerCatalog.cs", r'new\(\s*"([^"]+)"'),
        )
        identities = []
        for path, pattern in catalogs:
            with self.subTest(platform=path.parts[-4]):
                source = path.read_text()
                ids = re.findall(pattern, source)
                self.assertEqual(ids.count("creed"), 1)
                self.assertEqual(ids.count("niceneCreed"), 1)
                self.assertEqual(ids.index("niceneCreed"), ids.index("creed") + 1)
                entry = source[source.index('"niceneCreed"'):].split(")", 1)[0]
                self.assertIn('"rosary"', entry)
                self.assertIn('"symbolumNicaenumTitle"', entry)
                self.assertIn('"symbolumNicaenum"', entry)
                self.assertIn('"crucifix"', entry)
                identities.append(set(ids))
        self.assertEqual(identities[0], identities[1])
        self.assertEqual(identities[0], identities[2])

    def test_source_owned_policy_replaces_the_user_preference(self):
        schema = json.loads((SHARED / "schema/domain-model.json").read_text())
        self.assertIn("$creedPolicy", schema["types"]["PrayerPackContent"]["fields"])
        self.assertTrue(schema["types"]["AppSettings"]["fields"]["includeFilioque"]["retired"])
        for language in ("arc", "he-x-gamliel", "uk"):
            policy = content(language)["$creedPolicy"]
            self.assertFalse(policy["apostlesCreed"])
            self.assertEqual(policy["filioque"], "bracketed")
        self.assertEqual(content("la")["$creedPolicy"]["filioque"], "unbracketed")
        self.assertTrue(content("he")["$creedPolicy"]["apostlesCreed"])
        self.assertFalse(content("el")["$creedPolicy"]["apostlesCreed"])

    def test_distributed_content_matches_canonical_sources_and_native_copies(self):
        pack = SHARED / "dist/rosary.prosaryprayer"
        with zipfile.ZipFile(pack) as archive:
            for language in ("he", "he-x-gamliel", "arc", "el", "la"):
                with self.subTest(language=language):
                    self.assertTrue(json.loads(archive.read(f"content/{language}.json")) == content(language),
                                    f"Rosary pack content/{language}.json is stale")
        for platform, path in PACK_PATHS:
            with self.subTest(platform=platform):
                self.assertTrue(path.read_bytes() == pack.read_bytes(), "Native packs must be byte-identical")


if __name__ == "__main__":
    unittest.main()
