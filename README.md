# Cairn — spolszczenie (nieoficjalne)

Pełne polskie tłumaczenie gry **[Cairn](https://store.steampowered.com/app/2356350/Cairn/)** (The Game Bakers, 2026). Polonizacja działa na bazowej instalacji ze Steam i jest budowana lokalnie z Twojej legalnej kopii gry — repozytorium nie zawiera plików gry.

| | |
|---|---|
| **Stan tłumaczenia** | 100% (3538/3538 niepustych stringów) |
| **Wersja gry** | testowane na buildzie ze Steam z 2026-05-02 |
| **Wersja Unity** | Unity 2022 (Addressables 2.7.3) |
| **Licencja kodu i tłumaczenia** | MIT (zobacz `LICENSE`) |
| **Pliki gry** | © The Game Bakers — NIE są częścią repo |

## Dla graczy — instalacja w 3 krokach

> **Wymagania:** Cairn na Steam + [Python 3.8+](https://www.python.org/downloads/) (przy instalacji zaznacz **„Add Python to PATH"**)

1. **Pobierz** repozytorium: zielony przycisk *Code → Download ZIP*, rozpakuj.
2. **Zamknij Cairn** (jeśli jest uruchomione).
3. **Uruchom** `installer/Zbuduj-i-zainstaluj.bat` (dwuklik). Skrypt sam wykryje grę, zainstaluje zależność `UnityPy` przez pip i podmieni paczki, robiąc kopię zapasową oryginałów.

W grze: **Settings → Language → English**. Zobaczysz polski tekst — polonizacja podmienia angielską paczkę, ponieważ to jedyny sposób, by gra ją załadowała bez modyfikowania katalogu Addressables.

**Odinstalowanie:** uruchom `installer/Odinstaluj.bat` — przywróci oryginał z kopii zapasowej.

## Po aktualizacji gry przez Steam

Steam zwykle nie nadpisuje zmodyfikowanych plików. Jeśli jednak po patchu gra wraca do angielskiego, ponownie uruchom `Zbuduj-i-zainstaluj.bat` — wykryje zmianę po hashu i zaktualizuje polonizację. Diagnostyka:

```powershell
python scripts/check_game_update.py
```

pokazuje, ile stringów zostało dodanych / zmienionych / usuniętych przez deweloperów względem snapshotu, na bazie którego powstała polonizacja.

## Dla deweloperów — jak to działa

### Format paczek
Cairn używa **Unity Addressables** (`StreamingAssets/aa/StandaloneWindows64/`). Każdy język to osobna paczka `.bundle` (LZ4) z jednym `MonoBehaviour` o strukturze:

```jsonc
{
  "m_Name": "English",
  "texts": [
    { "flags": [...], "keys": [{"id": {"value": int}, "text": "..."}, ...] },
    ...  // 3 tabele (główne UI + dwie podtabele do remap kontrolera)
  ]
}
```

Klucz `id` to 32-bitowy int (najprawdopodobniej Murmur/CRC angielskiego źródła), stabilny między buildami dopóki tekst nie zmieni się po stronie deweloperów.

### Strategia tłumaczenia
**Podmieniamy paczkę angielską** zamiast dodawać nowy język. Powód: dodanie nowego języka wymagałoby modyfikacji `catalog.bin` Addressables (binarny format Unity, niełatwo odtwarzalny), a angielski jest uniwersalnym fallbackiem dostępnym dla każdego gracza.

### Strategia fontów
Oryginalne SDF-y w `dynamicfontsen_assets_all.bundle` to atlas o 102 glifach ASCII bez polskich znaków. Zamiast piec własny SDF (czas + ryzyko różnic wizualnych z oryginałem), **przełączamy `m_AtlasPopulationMode` z 0 (Static) na 1 (Dynamic)** — TextMeshPro w runtimie generuje SDF dla brakujących glifów ze źródłowego TTF. Zaszyte w grze fonty `Boxed-Bold/DemiBold/DemiBoldItalic/RegularItalic` oraz `LiberationSans` mają już komplet `ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ` — zweryfikowane przez `fonttools`.

Plus: jakość 1:1 z oryginałem, prawidłowe skalowanie.
Minus: niewielki „flash" przy pierwszym wyświetleniu nowego znaku (TMP go wtedy bake'uje).

### Pipeline

```
strings_pl.json
       │
       ▼ scripts/build_pl_bundle.py    (UnityPy)
localizationen_assets_all.bundle (PL)
       │
       ▼ scripts/build_pl_fonts.py
dynamicfontsen_assets_all.bundle (dynamic atlas)
       │
       ▼ installer/Install-CairnPL.ps1
[Cairn install: kopia zapasowa + podmiana]
```

### Dodawanie tłumaczeń

1. Stwórz plik `translations/batches/batch_NNNN.py` z dictem `PL = {(table, id): "polski tekst", ...}`.
2. `python scripts/apply_translations.py translations/batches/batch_NNNN.py`
3. `python scripts/build_distribution.py` — przebuduje paczki i ZIP.

### Testowanie po patchu

```powershell
python scripts/check_game_update.py
```

Dla każdego stringa, który deweloperzy zmienili lub dodali, narzędzie wypluje wpis do `translations/_diff.json`. Wystarczy dotłumaczyć nowe i zbudować ponownie.

## Struktura repozytorium

```
.
├── translations/
│   ├── strings_pl.json   # Główne źródło tłumaczeń (3980 wpisów, 100% pokrycia)
│   └── batches/          # Iteracyjne batche tłumaczeń (historia)
├── scripts/              # Pipeline build (Python + UnityPy)
├── installer/            # PowerShell + .bat dla użytkownika końcowego
├── README.md             # Ten plik
└── LICENSE               # MIT
```

Pominięte (`.gitignore`): `source/` (oryginalne paczki gry), `build/`, `dist/`, `installer/payload/`, `work/`, `translations/chunks_en/` — wszystko, co zawiera lub generuje materiał chroniony prawami autorskimi The Game Bakers.

## Zastrzeżenia prawne

- Polonizacja jest **fan-made**, niezwiązana z The Game Bakers.
- Repozytorium zawiera **wyłącznie** moje tłumaczenie (tekst) oraz skrypty narzędziowe.
- Pliki binarne gry nie są dystrybuowane — instalator buduje paczkę PL lokalnie z **Twojej własnej legalnej kopii** Cairn ze Steam.
- Wszelkie znaki towarowe i prawa autorskie do gry należą do **The Game Bakers**.
- Kup Cairn legalnie: https://store.steampowered.com/app/2356350/Cairn/

## Wkład

PR-y z poprawkami tłumaczenia mile widziane! Zmiany w `translations/strings_pl.json` lub nowy plik w `translations/batches/`. Po PR-ze zostanie scalone i wydany nowy build.
