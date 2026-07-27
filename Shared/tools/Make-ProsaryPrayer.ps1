<#
.SYNOPSIS
Packs a devotion's authored source directory (Shared/content/<devotion>/) into a
.prosaryprayer bundle (a zip archive -- see Shared/ARCHITECTURE.md for the format).

.PARAMETER SourceDir
Path to a devotion's source directory, e.g. Shared/content/rosary.

.PARAMETER OutputPath
Defaults to Shared/dist/<manifest id>.prosaryprayer.

.EXAMPLE
./Make-ProsaryPrayer.ps1 -SourceDir ../content/rosary
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Test-JsonFile($Path) {
    if (-not (Test-Path $Path)) {
        Fail "missing file: $Path"
    }
    try {
        Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json | Out-Null
    } catch {
        Fail "$Path is not valid JSON: $_"
    }
}

$SourceDir = (Resolve-Path $SourceDir).Path
$SharedDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ImagesDir = Join-Path $SharedDir "Images"

$ManifestPath = Join-Path $SourceDir "manifest.json"
Test-JsonFile $ManifestPath
$Manifest = Get-Content -Raw -Encoding UTF8 $ManifestPath | ConvertFrom-Json

$DevotionId = $Manifest.id
Write-Host "Packing '$DevotionId' from $SourceDir"

if (-not $OutputPath) {
    $OutputPath = Join-Path $SharedDir "dist/$DevotionId.prosaryprayer"
}

foreach ($Lang in $Manifest.languages) {
    $LangFile = Join-Path $SourceDir "content/$Lang.json"
    Test-JsonFile $LangFile
}

if ($Manifest.hasCatalog) {
    $CatalogPath = Join-Path $SourceDir "catalog.json"
    Test-JsonFile $CatalogPath
}

foreach ($ImageKey in $Manifest.images) {
    $ImagePath = Join-Path $ImagesDir "$ImageKey.jpg"
    if (-not (Test-Path $ImagePath)) {
        Fail "manifest declares image '$ImageKey' but $ImagePath is missing"
    }
}

# Stage the bundle contents, then zip.
$StageDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $StageDir | Out-Null
try {
    Copy-Item $ManifestPath (Join-Path $StageDir "manifest.json")

    $StageContentDir = Join-Path $StageDir "content"
    New-Item -ItemType Directory -Path $StageContentDir | Out-Null
    Copy-Item (Join-Path $SourceDir "content/*.json") $StageContentDir

    if ($Manifest.hasCatalog) {
        Copy-Item (Join-Path $SourceDir "catalog.json") (Join-Path $StageDir "catalog.json")
    }

    $StageImagesDir = Join-Path $StageDir "images"
    New-Item -ItemType Directory -Path $StageImagesDir | Out-Null
    foreach ($ImageKey in $Manifest.images) {
        Copy-Item (Join-Path $ImagesDir "$ImageKey.jpg") (Join-Path $StageImagesDir "$ImageKey.jpg")
    }

    $OutputDir = Split-Path -Parent $OutputPath
    if ($OutputDir -and -not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }
    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath
    }

    # Compress-Archive requires a .zip extension, so build as .zip and rename.
    $TempZip = [System.IO.Path]::ChangeExtension($OutputPath, ".zip")
    if (Test-Path $TempZip) {
        Remove-Item $TempZip
    }
    Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $TempZip -CompressionLevel Optimal
    Move-Item $TempZip $OutputPath

    $FileCount = (Get-ChildItem -Recurse -File $StageDir).Count
    $ByteSize = (Get-Item $OutputPath).Length
    Write-Host "Wrote $OutputPath ($FileCount files, $ByteSize bytes)"
} finally {
    Remove-Item -Recurse -Force $StageDir
}
