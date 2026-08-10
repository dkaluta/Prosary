<#
.SYNOPSIS
Downloads every external data source the repo's tooling needs -- today that is the scripture
editions import-scripture.py derives Aramaic/Greek/Spanish content from (ETCBC Peshitta,
Byzantine text/LXX, Torres Amat) -- into Shared/tools/.scripture-cache, so later runs work
offline. Idempotent: already-cached files are never re-fetched.

The list of WHAT to download lives in import-scripture.py itself (the citations decide);
this is a thin wrapper, twinned with download-data.sh for macOS/Linux.

Requires uv (https://docs.astral.sh/uv/).

.EXAMPLE
./Download-Data.ps1
#>

$ErrorActionPreference = "Stop"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Error "uv is required -- install it from https://docs.astral.sh/uv/"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
uv run --script (Join-Path $ScriptDir "import-scripture.py") --prefetch
exit $LASTEXITCODE
