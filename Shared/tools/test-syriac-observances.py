#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests"]
# ///
"""Offline regression cases from the published English and Arabic Syriac editions."""
import importlib.util
import json
import re
import tempfile
from collections import Counter
from pathlib import Path
from unittest.mock import patch
import requests

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("feasts", TOOLS / "fetch-feasts.py")
feasts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feasts)
fixtures = json.loads((TOOLS / "fixtures/syriac-observances.json").read_text())["days"]
identities = feasts.syriac_identities()
LANGUAGES = ("en", "he", "ar", "ru", "tl", "fr", "it", "uk")
CATALOG_LANGUAGES = tuple(language for language in LANGUAGES if language not in {"en", "ar"})


def reviewed_catalogs():
    """Read the credited names independently of the generator's localization helpers."""
    catalogs = {language: {} for language in CATALOG_LANGUAGES}
    for path in feasts.DISPLAY_TITLE_CATALOGS:
        for title, values in json.loads(path.read_text())["titles"].items():
            for language in CATALOG_LANGUAGES:
                if language in values:
                    catalogs[language][title] = values[language]
    for path in feasts.HEBREW_TITLE_CATALOGS:
        for title, values in json.loads(path.read_text())["titles"].items():
            assert values["source"] and values["he"], (path.name, title)
            catalogs["he"][title] = values["he"]
    for event in json.loads(feasts.LOCALIZED_TITLE_CATALOG.read_text())["events"].values():
        for language, value in event["titleByLanguage"].items():
            if language not in catalogs:
                continue
            assert event["sources"][language] and value
            for title in event["englishTitles"] + event.get("reviewedEnglishAliases", []):
                catalogs[language][title] = value
    return catalogs


def alias_path(title, aliases):
    path = [title]
    while title in aliases:
        title = aliases[title]
        assert title not in path, ("Cyclic reviewed alias", path, title)
        path.append(title)
    return path


reviewed_names = reviewed_catalogs()
all_aliases = json.loads((TOOLS / "feast-title-aliases.json").read_text())["aliases"] | identities[1]


def reviewed_name(identity, language):
    catalog = reviewed_names[language]
    # Exact identity names take precedence. Only reviewed aliases may supply a missing name;
    # never look up an ambiguous component display name such as plain "St. Matthew".
    for title in alias_path(identity, all_aliases):
        if title in catalog:
            return catalog[title]
    for title, value in catalog.items():
        if alias_path(title, identities[1])[-1] == identity:
            return value
    return None

def build(date):
    row = fixtures[date]
    return feasts.syriac_day(row["SYE"], row["SYA"], identities)

september = build("2026-09-30")
assert september["title"] == "St. Gregory the Illuminator; St. Jerome of Stridon", september
assert "غريغوريوس" in september["titleByLanguage"]["ar"]
assert "هيرونيموس" in september["titleByLanguage"]["ar"]
october = build("2026-10-01")
assert october["title"] == ("St. Ananias; St. Abi; "
                            "Saint Thérèse of the Child Jesus, Virgin and Doctor of the Church"), october
assert all(name in october["titleByLanguage"]["ar"] for name in ("حننيا", "أباي", "تريزا"))
january = build("2026-01-01")
assert "Circumcision" in january["title"] and "Peace" in january["title"], january
assert len(january["title"].split("; ")) == 3, january
assert "Hanania" not in january["title"] and "Therese" not in january["title"]
assert build("2026-01-09") is None
# These editions genuinely list different saints. Retain both, not same-position matching.
january31 = build("2026-01-31")
assert "Cyrus" in january31["title"] and "Bosco" in january31["title"], january31
assert build("2026-02-02") is not None  # Arabic-only observance, English is ferial.
july = build("2026-07-21")
assert len(july["title"].split("; ")) == 2 and "Stylites" in july["title"], july
assert "Stylites" in july["titleByLanguage"]["ar"], july  # untranslated source remains visible
assert july["titleByLanguage"]["ar"].count("شمعون") == 1, july
assert july["title"].startswith("St. Simeon Stylites; "), july

# UUIDs disambiguate reused names without replacing their published English spelling.
for date, source_name, reviewed_identity in (
    ("2026-01-15", "St. John", "Saint John the Hermit"),
    ("2026-05-08", "St. John", "Saint John, Apostle and Evangelist"),
    ("2026-09-18", "St. Matthew", "Saint Matthew the Hermit, Confessor and Abbot"),
    ("2026-11-16", "St. Matthew", "Saint Matthew, Apostle"),
    ("2026-10-11", "St. Philip", "Saint Philip the Deacon"),
    ("2026-11-14", "St. Philip", "Saint Philip the Apostle"),
):
    row = build(date)
    assert {"title": source_name, "identity": reviewed_identity} in row["observances"], row
    assert row["title"].split("; ").count(source_name) == 1, row
assert "Matthias" in build("2026-08-09")["title"]  # Distinct from English Matthew.

# Localize by identity, never by an ambiguous source display name or date.
catalog = feasts.syriac_identity_catalog({
    "Feast of Saint Hanania the Apostle": "Reviewed Ananias translation",
    "St. Matthew": "Wrong apostle translation for a hermit",
    "Saint Matthew, Apostle": "Reviewed apostle translation",
})
assert feasts.localized_feast_entry_title(october, catalog).startswith("Reviewed Ananias translation; St. Abi;")
assert feasts.localized_feast_entry_title(build("2026-09-18"), catalog) is None
assert feasts.localized_feast_entry_title(build("2026-11-16"), catalog) == "Reviewed apostle translation"

# Exercise mixed translated/source components separately for every localized interface. These
# are test markers, not authored prayer or feast translations. An unreviewed name must not
# disappear, and an ambiguous display-name alias must not override its reviewed identity.
for language in CATALOG_LANGUAGES:
    marker = f"Reviewed name ({language})"
    source_title = "St. Uncatalogued Source Name"
    case = {"title": f"St. Matthew; {source_title}", "observances": [
        {"title": "St. Matthew", "identity": "Saint Matthew the Hermit, Confessor and Abbot"},
        {"title": source_title, "identity": "Uncatalogued identity"},
    ], "titleByLanguage": {"ar": "Published Arabic caption"}}
    labels = {"St. Matthew": "Wrong apostle label", "Saint Matthew the Hermit, Confessor and Abbot": marker}
    if language == "he":
        feasts.localize_feast_days({"test": case}, labels)
    else:
        feasts.add_sourced_feast_titles({"test": case}, {language: labels})
    assert case["titleByLanguage"] == {"ar": "Published Arabic caption", language: f"{marker}; {source_title}"}, language
    assert case["title"] == f"St. Matthew; {source_title}", language
    assert feasts.localized_feast_entry_title(case, {"St. Matthew": "Wrong apostle label"}) is None, language

# Repeated identical source rows collapse; an untranslated Arabic saint stays visible.
base = {"liturgic_title": "Sunday of Pascha", "saints": [{"name": "St. Example"}] * 2}
arabic = {"liturgic_title": "الفصح", "saints": [{"name": "اسم غير مفهرس"}]}
row = feasts.syriac_day(base, arabic, ({}, {}, {}))
assert row["rank"] == "Great Feast" and row["title"].count("St. Example") == 1
assert "اسم غير مفهرس" in row["title"]
row = feasts.syriac_day({"liturgic_title": "Sunday after Epiphany", "saints": []},
                       {"liturgic_title": "الأحد", "saints": [{"name": "Named Fast"}]}, ({}, {}, {}))
assert row["rank"] == "Sunday"

# An invalid date/API failure is not a future horizon; do not silently truncate output.
response = requests.Response()
response.status_code = 400
response._content = b'{"message":"invalid edition"}'
with patch.object(feasts, "fetch_json", side_effect=requests.HTTPError(response=response)), patch.object(feasts.time, "sleep"):
    try:
        feasts.evangelizo_day("SYA", "2026-09-30")
        raise AssertionError("Invalid feed response must abort regeneration")
    except requests.HTTPError:
        pass
response._content = b'{"message":"This date is too far in the future"}'
with patch.object(feasts, "fetch_json", side_effect=requests.HTTPError(response=response)):
    assert feasts.evangelizo_day("SYA", "2026-12-31") is None

for invalid in (None, {}, {"date": "2026-09-30", "liturgic_title": "Day", "saints": None},
                {"date": "2026-09-30", "liturgic_title": None, "saints": []},
                {"date": "2026-09-30", "liturgic_title": "Day", "saints": [{"name": ""}]}):
    with patch.object(feasts, "fetch_json", return_value={"data": invalid}):
        try:
            feasts.evangelizo_day("SYA", "2026-09-30")
            raise AssertionError("Incomplete success must abort regeneration")
        except ValueError:
            pass
for results in ((None, fixtures["2026-01-01"]["SYA"]), (fixtures["2026-01-01"]["SYE"], None)):
    with patch.object(feasts, "evangelizo_day", side_effect=results):
        try:
            feasts.syriac_days(2026)
            raise AssertionError("Mismatched horizons must not silently drop one edition")
        except ValueError as error:
            assert "horizons disagree" in str(error)

canonical = json.loads((TOOLS.parent / "data/feasts-syriac.json").read_text())["days"]
fallback_counts = Counter()
fallback_identities = {language: set() for language in LANGUAGES if language != "en"}
coverage = {language: Counter() for language in LANGUAGES}
for date, row in canonical.items():
    components = row["observances"]
    assert components and all(part["title"] and part["identity"] for part in components), date
    assert row["title"] == "; ".join(part["title"] for part in components), date
    assert len({part["identity"] for part in components}) == len(components), date
    for language in LANGUAGES:
        display = row["title"] if language == "en" else row["titleByLanguage"][language]
        parts = display.split("; ")
        assert len(parts) == len(components), (date, language, display, components)
        assert all(part.strip() for part in parts), (date, language)
        for component, text in zip(components, parts, strict=True):
            identity = component["identity"]
            coverage[language][identity] += 1
            if language == "en":
                assert text == component["title"], (date, language, component)
                continue
            if language == "ar":
                # Published source captions win over translated metadata. Where an exact
                # Arabic caption has been reviewed, verify its identity in this position.
                if text in identities[0]:
                    assert alias_path(identities[0][text], identities[1])[-1] == identity, (date, text, component)
                fallback = text == component["title"]
            else:
                localized = reviewed_name(identity, language)
                expected = localized or component["title"]
                if language == "he":
                    expected = re.sub(r"(?<=[\u0590-\u05ff])-(?=[\u0590-\u05ff0-9])", "־", expected)
                assert text == expected, (date, language, identity, text, expected)
                fallback = localized is None
            if fallback:
                fallback_counts[language] += 1
                fallback_identities[language].add(identity)
assert all(counts == coverage["en"] for counts in coverage.values())

# The same published English label belongs to distinct saints. Missing reviewed translations
# of the hermit retain his source name in every locale, never the apostle's catalog entry.
for language in CATALOG_LANGUAGES:
    hermit = canonical["2026-09-18"]
    hermit_identity = hermit["observances"][0]["identity"]
    assert hermit["titleByLanguage"][language] == (reviewed_name(hermit_identity, language) or "St. Matthew"), language
    apostle = canonical["2026-11-16"]
    apostle_identity = apostle["observances"][0]["identity"]
    assert apostle_identity != hermit_identity
    assert apostle["titleByLanguage"][language] == (reviewed_name(apostle_identity, language) or "St. Matthew"), language
for date in fixtures:
    expected = build(date)
    if expected is None:
        assert date not in canonical, date
    else:
        assert canonical[date]["title"] == expected["title"], date
        assert canonical[date]["rank"] == expected["rank"], date
        assert canonical[date]["observances"] == expected["observances"], date
        assert canonical[date]["titleByLanguage"]["ar"] == expected["titleByLanguage"]["ar"], date

# Re-localizing an existing dataset keeps source spellings, identity metadata and Arabic.
with tempfile.TemporaryDirectory() as directory:
    fixture_data = Path(directory)
    for name in ("feasts-syriac.json", "calendars.json"):
        (fixture_data / name).write_bytes((TOOLS.parent / "data" / name).read_bytes())
    before = (fixture_data / "feasts-syriac.json").read_bytes()
    with patch.object(feasts, "DATA", fixture_data):
        feasts.localize_existing_datasets({"feasts-syriac"})
        assert (fixture_data / "feasts-syriac.json").read_bytes() == before
        feasts.localize_existing_datasets({"feasts-syriac"})
        assert (fixture_data / "feasts-syriac.json").read_bytes() == before
for target in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
    assert (TOOLS.parent / "data/feasts-syriac.json").read_bytes() == (TOOLS.parents[1] / target / "feasts-syriac.json").read_bytes()
print(f"All eight locales retain {sum(coverage['en'].values())} observances across {len(canonical)} dates "
      f"({len(coverage['en'])} distinct identities).")
print("Source-name fallbacks by locale (observance occurrences / distinct identities): " + "; ".join(
    f"{language}: {fallback_counts[language]} / {len(fallback_identities[language])}"
    for language in LANGUAGES if language != "en"))
print("English source names, reviewed locale names, Arabic captions, identity coverage, source errors and native data parity passed.")
