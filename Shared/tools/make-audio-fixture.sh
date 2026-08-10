#!/bin/bash
# Builds Shared/tools/fixtures/kyrieaudiodemo.prosaryprayer — the audio-playback test bundle:
# the Kyrie devotion (same shape as the repository seed) plus macOS-TTS narrations in Latin
# (Italian voice) and English, with audio.json chapters at the measured section boundaries so
# chapter→step syncing is exercised end to end. TTS is for testing only — real recordings
# replace it before any audio bundle ships to users (macOS `say` output is not redistributable
# content, and it prays badly anyway).
#
# Requires macOS (`say`, `afconvert`-era toolchain) and ffmpeg. Idempotent; run from anywhere.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/Shared/tools/fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT_DIR" "$WORK/bundle/audio" "$WORK/bundle/content" "$WORK/tts"

# --- The devotion itself: the Kyrie, under a compose-shaped id that can never collide with
# --- the repository seed (repo.* ids contain dots; compose ids cannot).
cat > "$WORK/bundle/manifest.json" <<'JSON'
{
  "schemaVersion": 1,
  "id": "kyrieaudiodemo",
  "kind": "kyrieaudiodemo",
  "displayName": "Kyrie (Audio Demo)",
  "languages": ["la", "en"],
  "hasCatalog": false,
  "images": [],
  "mainPrayerKeysOmitted": ["signumCrucis", "gloriaPatri"],
  "accentColorHex": "#7A1F3D",
  "accentColorDarkHex": "#D8A8B5",
  "iconSystemName": "waveform"
}
JSON

# Same shape as the repository seed bundle (repo.dkaluta.kyrie), which validates clean.
cat > "$WORK/bundle/devotion.json" <<'JSON'
{
  "type": "steps",
  "steps": [
    { "title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix" },
    { "titleKey": "step02Title", "bodyKey": "step02Body", "imageKey": "cross_placeholder", "repeat": 3 },
    { "title": "Glory Be", "bodyKey": "gloriaPatri", "imageKey": "glory_be" }
  ]
}
JSON

cat > "$WORK/bundle/content/la.json" <<'JSON'
{
  "prayers": {
    "step02Title": "Kyrie",
    "step02Body": "Kyrie, eleison.\n**Christe, eleison.**\nKyrie, eleison."
  },
  "mysteries": {}
}
JSON

cat > "$WORK/bundle/content/en.json" <<'JSON'
{
  "prayers": {
    "step02Title": "Kyrie",
    "step02Body": "Lord, have mercy.\n**Christ, have mercy.**\nLord, have mercy."
  },
  "mysteries": {}
}
JSON

# --- Narration: one spoken section per built step (cross, Kyrie ×3, Gloria), 0.5 s of silence
# --- between sections; chapter starts are the measured cumulative offsets.
GAP=0.5
ffmpeg -y -loglevel error -f lavfi -i "anullsrc=r=48000:cl=mono" -t $GAP "$WORK/tts/gap.wav"

narrate() { # narrate <voice> <outfile.wav> <text>
  say -v "$1" -o "$WORK/tts/section.aiff" "$3"
  ffmpeg -y -loglevel error -i "$WORK/tts/section.aiff" -ac 1 -ar 48000 "$2"
}

build_track() { # build_track <lang> <voice> <cross> <kyrie> <gloria>
  local lang=$1 voice=$2
  narrate "$voice" "$WORK/tts/$lang-cross.wav" "$3"
  narrate "$voice" "$WORK/tts/$lang-kyrie.wav" "$4"
  narrate "$voice" "$WORK/tts/$lang-gloria.wav" "$5"
  {
    echo "file '$WORK/tts/$lang-cross.wav'";  echo "file '$WORK/tts/gap.wav'"
    for _ in 1 2 3; do echo "file '$WORK/tts/$lang-kyrie.wav'"; echo "file '$WORK/tts/gap.wav'"; done
    echo "file '$WORK/tts/$lang-gloria.wav'"
  } > "$WORK/tts/$lang-list.txt"
  ffmpeg -y -loglevel error -f concat -safe 0 -i "$WORK/tts/$lang-list.txt" \
    -ac 1 -ar 48000 -c:a libopus -b:a 32k "$WORK/bundle/audio/$lang.opus"
}

build_track la Alice \
  "In nomine Patris, et Filii, et Spiritus Sancti. Amen." \
  "Kyrie, eleison. Christe, eleison. Kyrie, eleison." \
  "Gloria Patri, et Filio, et Spiritui Sancto. Sicut erat in principio, et nunc, et semper, et in saecula saeculorum. Amen."

build_track en Samantha \
  "In the name of the Father, and of the Son, and of the Holy Spirit. Amen." \
  "Lord, have mercy. Christ, have mercy. Lord, have mercy." \
  "Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen."

# --- audio.json from the measured durations.
uv run python - "$WORK" <<'PY'
import json, subprocess, sys
work = sys.argv[1]
GAP = 0.5

def dur(path):
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", path]).strip())

def chapters(lang, titles):
    cross = dur(f"{work}/tts/{lang}-cross.wav")
    kyrie = dur(f"{work}/tts/{lang}-kyrie.wav")
    starts, t = [0.0], cross + GAP
    for _ in range(2):
        starts.append(t); t += kyrie + GAP
    starts.append(t); t += kyrie + GAP
    starts.append(t)
    # start[0]=cross, 1..3 the three Kyries, 4 the Gloria
    starts = [starts[0], starts[1], starts[2], starts[3], starts[4]]
    return [{"start": round(s, 2), "title": titles[i], "stepIndex": i}
            for i, s in enumerate(starts)]

tracks = [
    {"id": "la", "language": "la", "file": "audio/la.opus", "name": "Latin narration",
     "chapters": chapters("la", ["Signum Crucis", "Kyrie I", "Kyrie II", "Kyrie III", "Gloria Patri"])},
    {"id": "en", "language": "en", "file": "audio/en.opus", "name": "English narration",
     "chapters": chapters("en", ["Sign of the Cross", "Kyrie I", "Kyrie II", "Kyrie III", "Glory Be"])},
]
with open(f"{work}/bundle/audio.json", "w") as f:
    json.dump({"tracks": tracks}, f, indent=2)
print("audio.json chapters:", [c["start"] for c in tracks[0]["chapters"]],
      "and", [c["start"] for c in tracks[1]["chapters"]])
PY

uv run --script "$ROOT/Shared/tools/validate-devotion.py" "$WORK/bundle"

rm -f "$OUT_DIR/kyrieaudiodemo.prosaryprayer"
(cd "$WORK/bundle" && zip -q -X -r "$OUT_DIR/kyrieaudiodemo.prosaryprayer" .)
ls -la "$OUT_DIR/kyrieaudiodemo.prosaryprayer"
