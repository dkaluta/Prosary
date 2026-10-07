#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Report every registered Psalm appointment separately for each source table.

Availability is not a semantic certification. Run the independent source and
numeric audits too; this report keeps sparse source gaps and calendar contexts
visible instead of folding newly registered calendars into a Roman total.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from reading_appointment_keys import DATA, registry_datasets, passage_key

ROOT = Path(__file__).resolve().parents[2]


def audit():
    raw = (DATA / "readings-texts.json").read_bytes()
    payload = json.loads(raw)
    report = json.loads((ROOT / "Shared/reports/readings-text-coverage.json").read_text())
    datasets = {}
    for identifier, registration in registry_datasets().items():
        path = DATA / (registration["file"] + ".json")
        table = json.loads(path.read_text()) if path.exists() else {}
        appointments = [reading for day in table.get("days", {}).values()
                        for reading in day.get("readings", []) if reading["full"].startswith("Psalm ")]
        keys = sorted({passage_key(reading["full"], identifier) for reading in appointments})
        coverage = {}
        for edition in payload["editions"]:
            eid = edition["id"]
            gaps = {key: report["unavailable"][key][eid] for key in keys
                    if eid not in payload["passages"].get(key, {})}
            coverage[eid] = {"available": len(keys) - len(gaps), "unavailable": len(gaps),
                             "reasons": dict(Counter(gaps.values())), "unavailableKeys": gaps}
        datasets[identifier] = {"file": registration["file"], "calendarIds": sorted(registration["calendarIds"]),
                               "sourceURL": table.get("sourceUrl"), "sourceSHA256": table.get("sourceSha256"),
                               "appointmentRows": len(appointments), "uniqueAppointments": len(keys),
                               "coverage": coverage}
    return {"schemaVersion": 1, "corpusSHA256": hashlib.sha256(raw).hexdigest(),
            "limits": ["Counts identify current available text, not a complete word-by-word translation review.",
                       "Unavailable keys retain their original printed citations; source-specific gaps are not silently filled from another calendar or edition."],
            "readingDatasets": datasets}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = audit()
    if args.report:
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    for identifier, dataset in result["readingDatasets"].items():
        if not dataset["uniqueAppointments"]:
            continue
        values = ", ".join(f"{edition}: {row['available']}/{dataset['uniqueAppointments']}"
                           for edition, row in dataset["coverage"].items())
        print(f"{identifier} — {dataset['appointmentRows']} Psalm rows — {values}")


if __name__ == "__main__":
    main()
