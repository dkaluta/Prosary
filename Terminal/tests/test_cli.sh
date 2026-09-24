#!/bin/sh
set -eu

temporary=$(mktemp -d "${TMPDIR:-/tmp}/prosary-cli.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
export XDG_STATE_HOME="$temporary/state"

./prosary --help > "$temporary/help"
./prosary --version > "$temporary/version"
./prosary --no-state --list > "$temporary/catalog"
test "$(wc -l < "$temporary/catalog" | tr -d ' ')" -ge 10
while read -r devotion rest; do
    ./prosary --no-state --dump "$devotion" --language en --group joyful > "$temporary/prayer"
    test -s "$temporary/prayer"
done < "$temporary/catalog"

./prosary --no-state --dump rosary --group joyful > "$temporary/rosary"
grep -q 'The Annunciation' "$temporary/rosary"
grep -q 'Hail Mary' "$temporary/rosary"
./prosary --no-state --dump rosary --language la > "$temporary/latin"
test -s "$temporary/latin"
./prosary --no-state --list --language fil > "$temporary/fil"
./prosary --no-state --list --language tl > "$temporary/tl"
cmp "$temporary/fil" "$temporary/tl"

# Option order must not silently select a different recension.
./prosary --no-state --dump trisagion --variant 2 --language la > "$temporary/form-first"
./prosary --no-state --dump trisagion --language la --variant 2 > "$temporary/language-first"
cmp "$temporary/form-first" "$temporary/language-first"

# A bookmark's form belongs to that devotion, not an unrelated --dump target.
cat > "$temporary/bookmark" <<'EOF'
prosary-terminal-state 1
devotion trisagion
defaultLanguageCode en
interfaceLanguageCode en
step 0
group 0
variant 1
day -1
completed 0
year 2026
month 9
dayOfMonth 23
EOF
./prosary --state "$temporary/bookmark" --dump angelus > "$temporary/other-devotion"
grep -q 'Angelus' "$temporary/other-devotion"
./prosary --no-state --dump franciscanCrown --language arc > "$temporary/fallback" 2> /dev/null
grep -q 'source' "$temporary/fallback"

if ./prosary --no-state --dump nonexistent > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state --language xyz --list > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state --dump rosary --group sideways > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state --dump rosary --day 99999999999999999 > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state --data "$temporary/missing" --list > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state --wat > /dev/null 2>&1; then exit 1; fi
if ./prosary --no-state < /dev/null > /dev/null 2>&1; then exit 1; fi
# Read-only operations never create a resume file.
test ! -e "$temporary/state"
printf '%s\n' 'CLI tests passed: catalog, all devotions, language aliases, errors, non-TTY use.'
