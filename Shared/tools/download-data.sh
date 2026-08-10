#!/bin/sh
# Downloads every external data source the repo's tooling needs — today that is the scripture
# editions import-scripture.py derives Aramaic/Greek/Spanish content from (ETCBC Peshitta,
# Byzantine text/LXX, Torres Amat) — into Shared/tools/.scripture-cache, so later runs work
# offline. Idempotent: already-cached files are never re-fetched.
#
# The list of WHAT to download lives in import-scripture.py itself (the citations decide);
# this is a thin wrapper, twinned with Download-Data.ps1 for the Windows machine.
#
# Requires: uv (https://docs.astral.sh/uv/).

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

command -v uv >/dev/null 2>&1 || {
  echo "error: uv is required — install it from https://docs.astral.sh/uv/" >&2
  exit 1
}

exec uv run --script "$SCRIPT_DIR/import-scripture.py" --prefetch
