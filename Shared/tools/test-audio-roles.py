#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Legacy narration and musical-prayer authoring rules against the real test recording."""
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent


def check(role, with_step_hints, expected_error=None):
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        with zipfile.ZipFile(TOOLS / "fixtures/kyrieaudiodemo.prosaryprayer") as fixture:
            fixture.extractall(work)
        path = work / "audio.json"
        audio = json.loads(path.read_text())
        for track in audio["tracks"]:
            if role is not None:
                track["role"] = role
            for chapter in track["chapters"]:
                if not with_step_hints:
                    chapter.pop("stepIndex", None)
        path.write_text(json.dumps(audio))
        result = subprocess.run([sys.executable, str(TOOLS / "validate-devotion.py"), str(work)],
                                capture_output=True, text=True)
        output = result.stdout + result.stderr
        if expected_error:
            assert result.returncode != 0 and expected_error in output, output
        else:
            assert result.returncode == 0, output


check(None, True)
check("narration", True)
check("music", False)
check("music", True, "music chapters must not contain stepIndex")
check("unknown", False, "role must be narration or music")
print("Audio roles: legacy narration, music, and invalid roles/hints all pass")
