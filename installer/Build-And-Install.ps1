# =============================================================================
# Cairn — build + instalacja w jednym kroku
# =============================================================================
# Skrypt dla użytkowników, którzy sklonowali repozytorium z GitHuba.
# Repozytorium NIE zawiera plików gry (z powodów prawnych) — ten skrypt:
#   1. wyszuka instalację Cairn ze Steam,
#   2. zbuduje spolszczone paczki .bundle z tłumaczeń (translations/strings_pl.json)
#      bezpośrednio na podstawie Twojej legalnej kopii gry,
#   3. zainstaluje je z kopią zapasową oryginałów.
#
# Wymagania: Python 3.8+ (https://www.python.org/downloads/)
# =============================================================================

[CmdletBinding()]
param(
    [string]$GamePath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

function Write-Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Write-OK($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Write-Err($m)  { Write-Host "[x] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host " Cairn — kompilacja i instalacja PL" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host ""

# 1. Sprawdź Pythona
Write-Step "Sprawdzam Pythona..."
try {
    $py = (& python --version 2>&1)
    Write-OK "Python: $py"
} catch {
    Write-Err "Python nie jest zainstalowany lub nie jest w PATH."
    Write-Host "Pobierz: https://www.python.org/downloads/  (zaznacz 'Add to PATH' przy instalacji)"
    [void][System.Console]::ReadLine()
    exit 1
}

# 2. Zainstaluj UnityPy jeśli brak
Write-Step "Sprawdzam zależności (UnityPy)..."
$installed = & python -c "import UnityPy" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Step "UnityPy nie jest zainstalowane — instaluję..."
    & python -m pip install --user UnityPy
    if ($LASTEXITCODE -ne 0) { throw "Nie udało się zainstalować UnityPy." }
}
Write-OK "UnityPy gotowe."

# 3. Wykryj grę
. "$ScriptDir\Install-CairnPL.ps1" -GamePath $GamePath -ErrorAction SilentlyContinue *> $null
# Powyższe nie jest dot-source, tylko żeby ewentualnie zwalić na default. Pójdziemy własną ścieżką:

if (-not $GamePath) {
    Write-Step "Wykrywanie instalacji Cairn..."
    $candidates = @()
    $steamRoot = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamRoot) {
        $steamRoot = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    }
    if ($steamRoot) {
        $candidates += $steamRoot
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($mt in $matches) { $candidates += $mt.Groups[1].Value.Replace('\\','\') }
        }
    }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 })) {
        $try1 = Join-Path $drive.Root "SteamLibrary"
        if (Test-Path $try1) { $candidates += $drive.Root }
    }
    foreach ($lib in $candidates | Sort-Object -Unique) {
        $p1 = Join-Path $lib "steamapps\common\Cairn"
        $p2 = Join-Path $lib "SteamLibrary\steamapps\common\Cairn"
        foreach ($p in @($p1, $p2)) {
            if (Test-Path (Join-Path $p "Cairn.exe")) { $GamePath = $p; break }
        }
        if ($GamePath) { break }
    }
}

if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath "Cairn.exe"))) {
    Write-Err "Nie znaleziono instalacji Cairn. Uruchom z parametrem: -GamePath ""C:\Sciezka\do\Cairn"""
    [void][System.Console]::ReadLine()
    exit 1
}

Write-OK "Wykryto Cairn: $GamePath"
$gameBundleDir = Join-Path $GamePath "Cairn_Data\StreamingAssets\aa\StandaloneWindows64"

# 4. Skopiuj oryginalne paczki do source/ (tylko lokalnie, jako wsad do builda)
Write-Step "Kopiuję oryginalne paczki gry do snapshotu..."
$srcDir = Join-Path $RepoRoot "source"
if (-not (Test-Path $srcDir)) { New-Item -ItemType Directory -Path $srcDir | Out-Null }
$bundles = @("localizationen_assets_all.bundle", "dynamicfontsen_assets_all.bundle", "dynamicfonts_assets_all.bundle")
foreach ($b in $bundles) {
    $src = Join-Path $gameBundleDir $b
    if (-not (Test-Path $src)) { throw "Brak pliku w grze: $src" }
    Copy-Item -Path $src -Destination $srcDir -Force
}
Write-OK "Snapshot gotowy."

# 5. Zbuduj paczki
Write-Step "Buduję paczkę z tekstami PL..."
Push-Location $RepoRoot
try {
    & python "scripts\build_pl_bundle.py"
    if ($LASTEXITCODE -ne 0) { throw "build_pl_bundle.py zwrócił błąd" }
    & python "scripts\build_pl_fonts.py"
    if ($LASTEXITCODE -ne 0) { throw "build_pl_fonts.py zwrócił błąd" }
}
finally { Pop-Location }
Write-OK "Paczki zbudowane w build/."

# 6. Skopiuj zbudowane paczki do payloadu i wywołaj instalator
Write-Step "Przygotowuję payload..."
$payloadDir = Join-Path $ScriptDir "payload"
if (-not (Test-Path $payloadDir)) { New-Item -ItemType Directory -Path $payloadDir | Out-Null }
foreach ($b in @("localizationen_assets_all.bundle", "dynamicfontsen_assets_all.bundle")) {
    Copy-Item -Path (Join-Path $RepoRoot "build\$b") -Destination $payloadDir -Force
}
Write-OK "Payload gotowy."

Write-Step "Uruchamiam instalator..."
& "$ScriptDir\Install-CairnPL.ps1" -GamePath $GamePath -Force
exit $LASTEXITCODE
