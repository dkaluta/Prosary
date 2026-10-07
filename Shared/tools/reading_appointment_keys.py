#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Registry-driven reading table identities, preserving legacy passage keys.

The original six tables keep their shared daily|citation contract. Additional
tables get daily|dataset|citation keys, so adding a calendar cannot borrow an
existing calendar's numbering review or invalidate its already reviewed text.
"""
from collections import defaultdict
import json
from pathlib import Path
import re

DATA = Path(__file__).resolve().parents[1] / "data"
LEGACY_DATASETS = frozenset({"roman", "roman1962", "ugcc", "ugcc-gregorian", "syriac", "maronite"})
_FILE = re.compile(r"readings-([a-z0-9][a-z0-9-]*)")


def registry_datasets(data: Path = DATA) -> dict[str, dict]:
    registry = json.loads((data / "calendars.json").read_text(encoding="utf-8"))
    result = {}
    for calendar in registry["calendars"]:
        entries = [calendar] + list(calendar.get("paschaVariants", {}).values())
        for entry in entries:
            filename = entry.get("readingsFile")
            if filename is None:
                continue
            match = _FILE.fullmatch(filename)
            if not match:
                raise ValueError("Invalid registered reading dataset filename")
            identifier = match[1]
            item = result.setdefault(identifier, {"file": filename, "calendarIds": set()})
            item["calendarIds"].add(calendar["id"])
    return result


def passage_key(citation: str, dataset: str | None = None, *, is_torah: bool = False) -> str:
    if not citation or "|" in citation:
        raise ValueError("Invalid opaque reading citation")
    if is_torah:
        return "torah|" + citation
    if dataset == "lpj":
        dataset = "roman"
    if dataset is None or dataset in LEGACY_DATASETS:
        return "daily|" + citation
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", dataset):
        raise ValueError("Invalid reading dataset identity")
    return f"daily|{dataset}|{citation}"


def split_passage_key(key: str) -> tuple[str, str, str | None]:
    parts = key.split("|")
    if len(parts) == 2 and parts[0] in {"daily", "torah"} and parts[1]:
        return parts[0], parts[1], None
    if (len(parts) == 3 and parts[0] == "daily" and parts[2]
            and re.fullmatch(r"[a-z0-9][a-z0-9-]*", parts[1])):
        return parts[0], parts[2], parts[1]
    raise ValueError("Invalid reading passage identity")


def appointments(data: Path = DATA) -> dict[str, set[str]]:
    result = defaultdict(set)
    for identifier, item in registry_datasets(data).items():
        path = data / (item["file"] + ".json")
        if not path.exists():
            continue  # An absent optional table has no invented appointments.
        table = json.loads(path.read_text(encoding="utf-8"))
        for day in table.get("days", {}).values():
            for reading in day.get("readings", []):
                result[passage_key(reading["full"], identifier)].add(identifier)
    torah = data / "torah-portions.json"
    if torah.exists():
        for day in json.loads(torah.read_text(encoding="utf-8"))["days"].values():
            for reading in day.get("readings", []):
                result[passage_key(reading["full"], is_torah=True)].add("torah")
    return dict(result)
