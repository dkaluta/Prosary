#!/bin/sh
# Packs a devotion's authored source directory (Shared/content/<devotion>/) into a
# .prosaryprayer bundle (a zip archive — see Shared/ARCHITECTURE.md for the format).
#
# Usage: make-prosaryprayer.sh <source-dir> [output-path]
#   source-dir   e.g. Shared/content/rosary
#   output-path  defaults to Shared/dist/<manifest id>.prosaryprayer
#
# Requires: uv (runs the Python tooling), zip (archive creation).

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SHARED_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
IMAGES_DIR="$SHARED_DIR/Images"

SRC_DIR=$1
OUT_PATH=$2

if [ -z "$SRC_DIR" ]; then
  echo "Usage: $0 <source-dir> [output-path]" >&2
  exit 1
fi
SRC_DIR=$(CDPATH= cd -- "$SRC_DIR" && pwd)

fail() {
  echo "error: $1" >&2
  exit 1
}

validate_json() {
  uv run python -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$1" \
    || fail "$1 is not valid JSON"
}

MANIFEST="$SRC_DIR/manifest.json"
[ -f "$MANIFEST" ] || fail "missing manifest.json in $SRC_DIR"
validate_json "$MANIFEST"

DEVOTION_ID=$(uv run python -c "import json; print(json.load(open('$MANIFEST', encoding='utf-8'))['id'])")
HAS_CATALOG=$(uv run python -c "import json; print(json.load(open('$MANIFEST', encoding='utf-8'))['hasCatalog'])")

if [ -z "$OUT_PATH" ]; then
  OUT_PATH="$SHARED_DIR/dist/$DEVOTION_ID.prosaryprayer"
fi

echo "Packing '$DEVOTION_ID' from $SRC_DIR"

# Validate every declared language file exists and parses.
uv run python -c "import json; [print(l) for l in json.load(open('$MANIFEST', encoding='utf-8'))['languages']]" |
while IFS= read -r LANG; do
  LANG_FILE="$SRC_DIR/content/$LANG.json"
  [ -f "$LANG_FILE" ] || fail "manifest declares language '$LANG' but $LANG_FILE is missing"
  validate_json "$LANG_FILE"
done

# Validate the catalog, if this devotion has one.
if [ "$HAS_CATALOG" = "True" ]; then
  CATALOG="$SRC_DIR/catalog.json"
  [ -f "$CATALOG" ] || fail "manifest says hasCatalog=true but $CATALOG is missing"
  validate_json "$CATALOG"
fi

# Validate every declared image exists in Shared/Images/.
uv run python -c "import json; [print(i) for i in json.load(open('$MANIFEST', encoding='utf-8'))['images']]" |
while IFS= read -r IMAGE_KEY; do
  [ -f "$IMAGES_DIR/$IMAGE_KEY.jpg" ] || fail "manifest declares image '$IMAGE_KEY' but $IMAGES_DIR/$IMAGE_KEY.jpg is missing"
done

# Deep-validate the devotion definition + per-language key resolution (see validate-devotion.py).
uv run --script "$SCRIPT_DIR/validate-devotion.py" "$SRC_DIR" || fail "devotion validation failed"

# Stage the bundle contents, then zip.
STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT

cp "$MANIFEST" "$STAGE_DIR/manifest.json"
mkdir -p "$STAGE_DIR/content"
cp "$SRC_DIR"/content/*.json "$STAGE_DIR/content/"
if [ "$HAS_CATALOG" = "True" ]; then
  cp "$SRC_DIR/catalog.json" "$STAGE_DIR/catalog.json"
fi
if [ -f "$SRC_DIR/devotion.json" ]; then
  validate_json "$SRC_DIR/devotion.json"
  cp "$SRC_DIR/devotion.json" "$STAGE_DIR/devotion.json"
fi
if [ -f "$SRC_DIR/options.json" ]; then
  validate_json "$SRC_DIR/options.json"
  cp "$SRC_DIR/options.json" "$STAGE_DIR/options.json"
fi
if [ -f "$SRC_DIR/audio.json" ]; then
  validate_json "$SRC_DIR/audio.json"
  cp "$SRC_DIR/audio.json" "$STAGE_DIR/audio.json"
  mkdir -p "$STAGE_DIR/audio"
  uv run python -c "import json; [print(t['file']) for t in json.load(open('$SRC_DIR/audio.json', encoding='utf-8'))['tracks']]" |
  while IFS= read -r AUDIO_FILE; do
    [ -f "$SRC_DIR/$AUDIO_FILE" ] || fail "audio.json declares '$AUDIO_FILE' but $SRC_DIR/$AUDIO_FILE is missing"
    cp "$SRC_DIR/$AUDIO_FILE" "$STAGE_DIR/$AUDIO_FILE"
  done
fi

mkdir -p "$STAGE_DIR/images"
uv run python -c "import json; [print(i) for i in json.load(open('$MANIFEST', encoding='utf-8'))['images']]" |
while IFS= read -r IMAGE_KEY; do
  cp "$IMAGES_DIR/$IMAGE_KEY.jpg" "$STAGE_DIR/images/$IMAGE_KEY.jpg"
done

mkdir -p "$(dirname "$OUT_PATH")"
rm -f "$OUT_PATH"
( cd "$STAGE_DIR" && zip -rq -X "$OUT_PATH" . -x '.DS_Store' -x '__MACOSX/*' )

FILE_COUNT=$(find "$STAGE_DIR" -type f | wc -l | tr -d ' ')
BYTE_SIZE=$(wc -c < "$OUT_PATH" | tr -d ' ')
echo "Wrote $OUT_PATH ($FILE_COUNT files, $BYTE_SIZE bytes)"
