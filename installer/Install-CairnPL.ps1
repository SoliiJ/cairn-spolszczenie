# =============================================================================
# Cairn — instalator polonizacji
# =============================================================================
# Wykrywa instalację gry, robi kopię zapasową oryginalnych paczek i podmienia
# je na wersje ze spolszczeniem. Obsługuje również odinstalowanie (przywrócenie
# z kopii) oraz wykrycie aktualizacji gry (porównanie hashy).
#
# Uruchomienie:
#   .\Install-CairnPL.ps1            -> instaluje
#   .\Install-CairnPL.ps1 -Uninstall -> przywraca oryginał
#   .\Install-CairnPL.ps1 -GamePath "G:\Sciezka\do\Cairn" -> jawna ścieżka
#
# Skrypt jest projektowany pod nadchodzące aktualizacje gry: gdy wykryje, że
# zapisany w kopii oryginał ma inny hash niż obecny plik gry, ostrzega
# użytkownika i pyta, czy nadpisać kopię (zachowując nowy oryginał) zanim
# wgra spolszczenie. Dzięki temu po aktualizacji ze Steama wystarczy uruchomić
# instalator ponownie.
# =============================================================================

[CmdletBinding()]
param(
    [string]$GamePath = "",
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$BundleNames = @(
    "localizationen_assets_all.bundle",
    "dynamicfontsen_assets_all.bundle"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadDir = Join-Path $ScriptDir "payload"
$ManifestPath = Join-Path $ScriptDir "manifest.json"

function Write-Step($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Write-OK($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[x] $m" -ForegroundColor Red }

function Find-CairnPath {
    if ($GamePath -and (Test-Path (Join-Path $GamePath "Cairn.exe"))) {
        return (Resolve-Path $GamePath).Path
    }

    Write-Step "Wykrywanie instalacji Cairn..."

    $candidates = @()
    $steamRoot = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamRoot) {
        $steamRoot = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    }
    if (-not $steamRoot) {
        $steamRoot = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    }

    $libraryFolders = @()
    if ($steamRoot) {
        $libraryFolders += $steamRoot
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($mt in $matches) {
                $libraryFolders += $mt.Groups[1].Value.Replace('\\','\')
            }
        }
    }

    foreach ($lib in $libraryFolders | Sort-Object -Unique) {
        $p = Join-Path $lib "steamapps\common\Cairn"
        if (Test-Path (Join-Path $p "Cairn.exe")) {
            $candidates += $p
        }
    }

    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 })) {
        $try1 = Join-Path $drive.Root "SteamLibrary\steamapps\common\Cairn"
        if ((Test-Path (Join-Path $try1 "Cairn.exe")) -and ($candidates -notcontains $try1)) {
            $candidates += $try1
        }
    }

    if ($candidates.Count -eq 0) {
        throw "Nie znaleziono instalacji Cairn. Podaj ścieżkę parametrem -GamePath ""C:\...\Cairn""."
    }

    return $candidates[0]
}

function Get-FileSha256($p) {
    if (-not (Test-Path $p)) { return $null }
    return (Get-FileHash -Algorithm SHA256 -Path $p).Hash
}

function Read-Manifest {
    if (Test-Path $ManifestPath) {
        return Get-Content $ManifestPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Write-Manifest($obj) {
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestPath -Encoding utf8
}

function Install-Translation {
    $game = Find-CairnPath
    Write-OK "Wykryto Cairn: $game"

    $bundleDir = Join-Path $game "Cairn_Data\StreamingAssets\aa\StandaloneWindows64"
    if (-not (Test-Path $bundleDir)) {
        throw "Nie znaleziono katalogu paczek: $bundleDir"
    }

    $backupDir = Join-Path $game "Cairn_Data\StreamingAssets\aa\StandaloneWindows64\_backup_PL"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

    $manifest = Read-Manifest
    if (-not $manifest) {
        $manifest = [pscustomobject]@{
            installedAt = (Get-Date).ToString("o")
            gamePath    = $game
            files       = @()
        }
    }

    $newFiles = @()
    foreach ($name in $BundleNames) {
        $payload = Join-Path $PayloadDir $name
        $target  = Join-Path $bundleDir $name
        $backup  = Join-Path $backupDir ($name + ".orig")

        if (-not (Test-Path $payload)) {
            Write-Err "Brak pliku w payload: $payload"
            throw "Niekompletna paczka instalatora."
        }
        if (-not (Test-Path $target)) {
            Write-Err "Brak pliku w grze: $target"
            throw "Wykryto niekompletną instalację gry albo zmienioną strukturę po aktualizacji."
        }

        $currentHash = Get-FileSha256 $target
        $payloadHash = Get-FileSha256 $payload

        if ($currentHash -eq $payloadHash) {
            Write-OK "$name jest już aktualną wersją PL — pomijam."
            continue
        }

        if (Test-Path $backup) {
            $backupHash = Get-FileSha256 $backup
            if ($backupHash -ne $currentHash) {
                # Plik gry różni się i od backupu, i od polonizacji = aktualizacja gry.
                Write-Warn "$name : oryginał gry zmienił się (prawdopodobnie aktualizacja Steam)."
                if (-not $Force) {
                    $ans = Read-Host "Nadpisać kopię zapasową nowym oryginałem i wgrać polonizację? [t/N]"
                    if ($ans -notmatch '^(t|tak|y|yes)$') {
                        Write-Warn "Pominięto plik $name."
                        continue
                    }
                }
                Copy-Item -Path $target -Destination $backup -Force
                Write-OK "Zaktualizowano kopię zapasową dla $name."
            }
        } else {
            Copy-Item -Path $target -Destination $backup -Force
            Write-OK "Utworzono kopię zapasową: $backup"
        }

        Copy-Item -Path $payload -Destination $target -Force
        Write-OK "Wgrano spolszczenie: $name"

        $newFiles += [pscustomobject]@{
            name        = $name
            originalSha = (Get-FileSha256 $backup)
            installedSha= (Get-FileSha256 $target)
        }
    }

    $manifest.installedAt = (Get-Date).ToString("o")
    $manifest.gamePath    = $game
    $manifest.files       = $newFiles
    Write-Manifest $manifest

    Write-OK "Instalacja polonizacji zakończona pomyślnie."
    Write-Host ""
    Write-Host "W grze upewnij się, że język jest ustawiony na ANGIELSKI (English) — polonizacja podmienia angielską paczkę." -ForegroundColor White
}

function Uninstall-Translation {
    $game = Find-CairnPath
    Write-OK "Wykryto Cairn: $game"

    $bundleDir = Join-Path $game "Cairn_Data\StreamingAssets\aa\StandaloneWindows64"
    $backupDir = Join-Path $bundleDir "_backup_PL"

    if (-not (Test-Path $backupDir)) {
        Write-Warn "Brak kopii zapasowej — polonizacja prawdopodobnie nie była zainstalowana."
        return
    }

    foreach ($name in $BundleNames) {
        $target = Join-Path $bundleDir $name
        $backup = Join-Path $backupDir ($name + ".orig")
        if (Test-Path $backup) {
            Copy-Item -Path $backup -Destination $target -Force
            Write-OK "Przywrócono oryginał: $name"
        } else {
            Write-Warn "Brak backupu dla $name — pomijam."
        }
    }

    Remove-Item -Recurse -Force $backupDir
    if (Test-Path $ManifestPath) { Remove-Item -Force $ManifestPath }

    Write-OK "Polonizacja odinstalowana — gra wróciła do stanu sprzed instalacji."
}

# --------- main ---------
try {
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host " Cairn — Instalator spolszczenia" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host ""

    if ($Uninstall) {
        Uninstall-Translation
    } else {
        Install-Translation
    }
}
catch {
    Write-Err $_.Exception.Message
    if (-not $Force) {
        Write-Host ""
        Write-Host "Naciśnij Enter, aby zamknąć..."
        [void][System.Console]::ReadLine()
    }
    exit 1
}

if (-not $Force) {
    Write-Host ""
    Write-Host "Naciśnij Enter, aby zamknąć..."
    [void][System.Console]::ReadLine()
}
