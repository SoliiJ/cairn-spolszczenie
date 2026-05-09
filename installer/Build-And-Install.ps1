# =============================================================================
# Cairn — build + instalacja w jednym kroku (dla uzytkownikow z GitHuba)
# =============================================================================
# Repozytorium NIE zawiera plikow gry (prawa autorskie The Game Bakers).
# Ten skrypt:
#   1. wyszuka instalacje Cairn ze Steam,
#   2. zbuduje spolszczone paczki .bundle z Twojego legalnego egzemplarza gry,
#   3. zainstaluje je z kopia zapasowa oryginalow.
#
# Wymagania: Python 3.9 - 3.13 (https://www.python.org/downloads/)
# UWAGA: Python 3.14 nie jest jeszcze obslugiwany przez UnityPy na Windows
# (brak prekompilowanych paczek dla zaleznosci jak Pillow / texture2ddecoder).
# =============================================================================

[CmdletBinding()]
param(
    [string]$GamePath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

function Write-Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Write-OK($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[x] $m" -ForegroundColor Red }

function Pause-Then-Exit($code) {
    Write-Host ""
    Write-Host "Nacisnij Enter, aby zamknac..."
    [void][System.Console]::ReadLine()
    exit $code
}

function Find-CairnPath([string]$hint) {
    if ($hint -and (Test-Path (Join-Path $hint "Cairn.exe"))) {
        return (Resolve-Path $hint).Path
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    $steamRoot = $null
    foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam")) {
        $p = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue)
        if ($p) {
            if ($p.SteamPath)   { $steamRoot = $p.SteamPath; break }
            if ($p.InstallPath) { $steamRoot = $p.InstallPath; break }
        }
    }

    if ($steamRoot) {
        $candidates.Add($steamRoot)
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw
            $rxMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($mt in $rxMatches) {
                $candidates.Add($mt.Groups[1].Value.Replace('\\','\'))
            }
        }
    }

    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free })) {
        $try = Join-Path $drive.Root "SteamLibrary"
        if (Test-Path $try) { $candidates.Add($try) }
    }

    foreach ($lib in ($candidates | Sort-Object -Unique)) {
        foreach ($p in @( (Join-Path $lib "steamapps\common\Cairn"), (Join-Path $lib "common\Cairn") )) {
            if (Test-Path (Join-Path $p "Cairn.exe")) { return $p }
        }
    }
    return $null
}

try {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host " Cairn - kompilacja i instalacja PL" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host ""

    # 1. Sprawdz Pythona
    Write-Step "Sprawdzam Pythona..."
    $pyOk = $false
    foreach ($cmd in @("python", "py")) {
        $pyExe = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($pyExe) {
            try {
                $ver = & $cmd --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "$cmd : $ver"
                    $script:PYTHON = $cmd
                    $pyOk = $true
                    break
                }
            } catch { }
        }
    }
    if (-not $pyOk) {
        Write-Err "Python nie jest zainstalowany lub nie jest w PATH."
        Write-Host "Pobierz: https://www.python.org/downloads/"
        Write-Host "Przy instalacji ZAZNACZ 'Add Python to PATH'."
        Pause-Then-Exit 1
    }

    # 1b. Sprawdz wersje Pythona (UnityPy nie ma jeszcze paczek dla 3.14 na Windows)
    $pyVer = & $PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($LASTEXITCODE -eq 0 -and $pyVer) {
        $parts = $pyVer.Trim().Split('.')
        $major = [int]$parts[0]
        $minor = [int]$parts[1]
        if ($major -ne 3 -or $minor -lt 9 -or $minor -gt 13) {
            Write-Err "Wykryto Python $pyVer. Wymagany jest Python 3.9 - 3.13."
            Write-Host ""
            Write-Host "Python 3.14 (i nowsze) nie ma jeszcze prekompilowanych paczek"
            Write-Host "dla UnityPy na Windows - pip probuje kompilowac ze zrodel i konczy"
            Write-Host "sie tracebackiem (brak kompilatora MSVC)."
            Write-Host ""
            Write-Host "Rozwiazanie:"
            Write-Host "  1. Odinstaluj obecnego Pythona (Panel sterowania -> Programy)."
            Write-Host "  2. Pobierz Pythona 3.13.x z https://www.python.org/downloads/"
            Write-Host "  3. Przy instalacji ZAZNACZ 'Add Python to PATH'."
            Write-Host "  4. Uruchom Zbuduj-i-zainstaluj.bat ponownie."
            Pause-Then-Exit 1
        }
    }

    # 2. Zainstaluj UnityPy jesli brak
    Write-Step "Sprawdzam UnityPy..."
    & $PYTHON -c "import UnityPy" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Instaluje UnityPy (pip install --user UnityPy)..."
        & $PYTHON -m pip install --user UnityPy
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Nie udalo sie zainstalowac UnityPy."
            Pause-Then-Exit 1
        }
    }
    Write-OK "UnityPy gotowe."

    # 3. Wykryj gre
    Write-Step "Wykrywanie instalacji Cairn..."
    $game = Find-CairnPath $GamePath
    if (-not $game) {
        Write-Err "Nie znaleziono instalacji Cairn."
        Write-Host "Uruchom rownie z parametrem:"
        Write-Host "  Build-And-Install.ps1 -GamePath ""C:\Sciezka\do\Cairn"""
        Pause-Then-Exit 1
    }
    Write-OK "Wykryto Cairn: $game"

    $gameBundleDir = Join-Path $game "Cairn_Data\StreamingAssets\aa\StandaloneWindows64"

    # 4. Skopiuj oryginalne paczki do source/ (lokalnie, wsad do builda)
    Write-Step "Kopiuje oryginalne paczki gry..."
    $srcDir = Join-Path $RepoRoot "source"
    if (-not (Test-Path $srcDir)) { New-Item -ItemType Directory -Path $srcDir | Out-Null }
    $bundles = @("localizationen_assets_all.bundle", "dynamicfontsen_assets_all.bundle", "dynamicfonts_assets_all.bundle")
    foreach ($b in $bundles) {
        $src = Join-Path $gameBundleDir $b
        if (-not (Test-Path $src)) {
            Write-Err "Brak pliku w grze: $src"
            Pause-Then-Exit 1
        }
        Copy-Item -Path $src -Destination $srcDir -Force
    }
    Write-OK "Snapshot gotowy."

    # 5. Zbuduj paczki (dwa kroki)
    Write-Step "Buduje paczke z tekstami PL..."
    Push-Location $RepoRoot
    try {
        & $PYTHON "scripts\build_pl_bundle.py"
        if ($LASTEXITCODE -ne 0) { throw "build_pl_bundle.py: blad" }
        & $PYTHON "scripts\build_pl_fonts.py"
        if ($LASTEXITCODE -ne 0) { throw "build_pl_fonts.py: blad" }
    }
    finally { Pop-Location }
    Write-OK "Paczki zbudowane."

    # 6. Wstaw do payloadu
    Write-Step "Przygotowuje payload..."
    $payloadDir = Join-Path $ScriptDir "payload"
    if (-not (Test-Path $payloadDir)) { New-Item -ItemType Directory -Path $payloadDir | Out-Null }
    foreach ($b in @("localizationen_assets_all.bundle", "dynamicfontsen_assets_all.bundle")) {
        Copy-Item -Path (Join-Path $RepoRoot "build\$b") -Destination $payloadDir -Force
    }
    Write-OK "Payload gotowy."

    # 7. Wywolaj instalator
    Write-Step "Uruchamiam instalator..."
    & "$ScriptDir\Install-CairnPL.ps1" -GamePath $game -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Instalator zwrocil blad."
        Pause-Then-Exit 1
    }
    Pause-Then-Exit 0
}
catch {
    Write-Err $_.Exception.Message
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Pause-Then-Exit 1
}
