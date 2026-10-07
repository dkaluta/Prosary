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


def rejects(action, text=None):
    try:
        action()
    except ValueError as error:
        assert text is None or text in str(error), error
    else:
        raise AssertionError("Invalid source or incomplete localization was accepted")


def components(row):
    return [(part["title"], part["identity"]) for part in row["observances"]]


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
    assert (source_name, reviewed_identity) in components(row), row
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

# Every locale must translate every reviewed unit; source fallback and partial compound
# translations cannot masquerade as complete coverage. Markers here are fixtures only.
from copy import deepcopy
localized_languages = tuple(language for language in LANGUAGES if language != "en")
def sample(identity="Fixture A"):
    return {"2026-01-01": {"title": identity, "observances": [{"title": identity, "identity": identity}]}}
labels = {language: {"Fixture A": f"Reviewed A ({language})", "Fixture B": f"Reviewed B ({language})"}
          for language in localized_languages}
with tempfile.TemporaryDirectory() as directory, patch.object(feasts, "TOOLS", Path(directory)):
    for language in localized_languages:
        missing = deepcopy(labels)
        missing[language].pop("Fixture A")
        rejects(lambda: feasts.localize_syriac_days(sample(), missing), "Untranslated Syriac")
        missing[language]["Fixture A"] = "  "
        rejects(lambda: feasts.localize_syriac_days(sample(), missing), "Untranslated Syriac")
    rejects(lambda: feasts.localize_syriac_days(sample("Fixture A; Fixture B"), labels), "Untranslated Syriac")
    partial = sample()
    assert len(feasts.localize_syriac_days(partial, {}, require_complete=False)) == 7
    assert partial["2026-01-01"]["titleByLanguage"] == {}
    (Path(directory) / "syriac-feast-titles-reviewed-test.json").write_text(
        json.dumps({"titles": {"Fixture A": {"fr": " "}}}))
    rejects(lambda: feasts.localize_syriac_days(sample(), labels), "Invalid reviewed Syriac translation")

# Published Arabic is immutable source metadata. Editorial Arabic can be refreshed on
# subsequent localizations and must never be mistaken for a newly published source caption.
case = sample()
case["2026-01-01"]["observances"][0]["sourceTitleByLanguage"] = {"ar": "النص المنشور (تذكار)"}
case["2026-01-01"]["observances"].append({"title": "Fixture B", "identity": "Fixture B"})
case["2026-01-01"]["title"] = "Fixture A; Fixture B"
feasts.localize_syriac_days(case, labels)
first = deepcopy(case)
feasts.localize_syriac_days(case, labels)
assert case == first
labels["ar"]["Fixture B"] = "Updated editorial Arabic marker"
feasts.localize_syriac_days(case, labels)
a, b = case["2026-01-01"]["observances"]
assert a["titleByLanguage"]["ar"] == a["sourceTitleByLanguage"]["ar"] == "النص المنشور (تذكار)"
assert b["titleByLanguage"]["ar"] == labels["ar"]["Fixture B"] and "sourceTitleByLanguage" not in b
with tempfile.TemporaryDirectory() as directory, patch.object(feasts, "DATA", Path(directory)):
    target = Path(directory) / "feasts-syriac.json"
    target.write_text("Last complete dataset")
    rejects(lambda: feasts.write_syriac_dataset(sample("Unreviewed future saint")), "Untranslated Syriac")
    assert target.read_text() == "Last complete dataset"

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
coverage = {language: Counter() for language in LANGUAGES}
assert "2026-02-10" not in canonical  # Published invalid spreadsheet marker, not a feast.
assert "#REF!" not in json.dumps(canonical)
assert len(canonical["2026-01-22"]["observances"]) == 1
assert canonical["2026-01-22"]["observances"][0]["identity"] == "St. Timothy"
for date, row in canonical.items():
    parts = row["observances"]
    assert parts and len({part["identity"] for part in parts}) == len(parts), date
    assert row["title"] == "; ".join(part["title"] for part in parts), date
    for language in LANGUAGES:
        values = [part["titleByLanguage"][language] for part in parts]
        assert all(isinstance(value, str) and value.strip() for value in values), (date, language)
        assert (row["title"] if language == "en" else row["titleByLanguage"][language]) == "; ".join(values)
        for part, value in zip(parts, values):
            coverage[language][part["identity"]] += 1
            if language == "en":
                assert value == part["title"]
            if language == "ar" and "ar" in part.get("sourceTitleByLanguage", {}):
                assert value == part["sourceTitleByLanguage"]["ar"], (date, part)
assert all(counts == coverage["en"] for counts in coverage.values())
# Genuine identical French names are allowed only by explicit reviewed catalog entries;
# completeness is established by exact lookup, not by rejecting all English-looking strings.
charles = next(part for day in canonical.values() for part in day["observances"]
               if part["identity"] == "Saint Charles de Foucauld")
assert charles["titleByLanguage"]["fr"] == "Saint Charles de Foucauld"
for date in fixtures:
    expected = build(date)
    if expected is None:
        assert date not in canonical, date
    else:
        assert canonical[date]["title"] == expected["title"], date
        assert canonical[date]["rank"] == expected["rank"], date
        assert components(canonical[date]) == components(expected), date
        for actual, source in zip(canonical[date]["observances"], expected["observances"]):
            if source.get("sourceTitleByLanguage", {}).get("ar"):
                assert actual["titleByLanguage"]["ar"] == source["sourceTitleByLanguage"]["ar"], date
# Arabic alone supplements a ferial English day without dropping its source identity.
assert components(canonical["2026-02-02"]) == components(build("2026-02-02"))
assert all(part["sourceTitleByLanguage"]["ar"] for part in canonical["2026-02-02"]["observances"])

# Re-localizing an existing dataset keeps source spellings, identity metadata and Arabic.
with tempfile.TemporaryDirectory() as directory:
    fixture_data = Path(directory)
    for name in ("feasts-syriac.json", "feasts-mission-provisional.json", "calendars.json"):
        (fixture_data / name).write_bytes((TOOLS.parent / "data" / name).read_bytes())
    before = (fixture_data / "feasts-syriac.json").read_bytes()
    provisional_before = (fixture_data / "feasts-mission-provisional.json").read_bytes()
    with patch.object(feasts, "DATA", fixture_data):
        feasts.localize_existing_datasets({"feasts-syriac"})
        assert (fixture_data / "feasts-syriac.json").read_bytes() == before
        feasts.localize_existing_datasets({"feasts-mission-provisional"})
        assert (fixture_data / "feasts-mission-provisional.json").read_bytes() == provisional_before
        feasts.localize_existing_datasets({"feasts-syriac"})
        assert (fixture_data / "feasts-syriac.json").read_bytes() == before
for target in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
    assert (TOOLS.parent / "data/feasts-syriac.json").read_bytes() == (TOOLS.parents[1] / target / "feasts-syriac.json").read_bytes()
print(f"All eight locales retain {sum(coverage['en'].values())} observances across {len(canonical)} dates "
      f"({len(coverage['en'])} distinct identities).")
print("All-language completeness, Arabic source preservation, editorial refresh, identity deduplication, source errors and native data parity passed.")
