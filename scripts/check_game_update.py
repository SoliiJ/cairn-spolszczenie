"""Check whether the Cairn install has been updated since we built the polonization.

Compares the SHA-256 of the in-game bundle against the SHA-256 we recorded the
last time we extracted English strings, and lists any string keys that
appeared, disappeared, or changed text.

Use after a Steam update to know whether you need to rebuild Polish translations.

Usage:
    python check_game_update.py [path-to-game-Cairn]
"""
import sys, json, hashlib
from pathlib import Path
import UnityPy

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_GAME = Path("G:/SteamLibrary/steamapps/common/Cairn")
SOURCE_BUNDLE = ROOT / "source" / "localizationen_assets_all.bundle"
EN_JSON = ROOT / "translations" / "strings_en.json"


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def load_strings(bundle_path):
    env = UnityPy.load(str(bundle_path))
    rows = []
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception:
            continue
        if not (isinstance(tree, dict) and "texts" in tree):
            continue
        for ti, table in enumerate(tree["texts"]):
            for entry in table.get("keys", []):
                rows.append({"table": ti, "id": entry["id"]["value"], "en": entry["text"]})
        break
    return rows


def main():
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_GAME
    live = game / "Cairn_Data/StreamingAssets/aa/StandaloneWindows64/localizationen_assets_all.bundle"
    if not live.exists():
        print(f"!! game bundle not found at {live}")
        sys.exit(1)

    if not SOURCE_BUNDLE.exists():
        print("!! reference snapshot not present (source/localizationen_assets_all.bundle)")
        sys.exit(1)

    snap_h = sha256(SOURCE_BUNDLE)
    live_h = sha256(live)
    print(f"snapshot: {snap_h}")
    print(f"live:     {live_h}")

    if snap_h == live_h:
        print("OK: game bundle is identical to our snapshot — no update needed.")
        return

    print("!! game bundle differs (likely a Steam update). Diffing strings...\n")

    snap = {(r["table"], r["id"]): r["en"] for r in json.load(open(EN_JSON, encoding="utf-8"))}
    live_rows = load_strings(live)
    livemap = {(r["table"], r["id"]): r["en"] for r in live_rows}

    added = sorted(set(livemap) - set(snap))
    removed = sorted(set(snap) - set(livemap))
    changed = [k for k in (set(snap) & set(livemap)) if snap[k] != livemap[k]]

    print(f"  + new strings:     {len(added)}")
    print(f"  - removed strings: {len(removed)}")
    print(f"  ~ changed strings: {len(changed)}")
    print()

    out = ROOT / "translations" / "_diff.json"
    diff = {
        "snap_sha256": snap_h,
        "live_sha256": live_h,
        "added":   [{"table": k[0], "id": k[1], "en": livemap[k]} for k in added],
        "removed": [{"table": k[0], "id": k[1], "en_old": snap[k]} for k in removed],
        "changed": [{"table": k[0], "id": k[1], "en_old": snap[k], "en_new": livemap[k]} for k in changed],
    }
    out.write_text(json.dumps(diff, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  wrote diff to {out}")
    print()
    print("Next steps:")
    print(f"  1. Refresh source snapshot:")
    print(f"       cp \"{live}\" \"{SOURCE_BUNDLE}\"")
    print(f"  2. Re-extract English strings: python scripts/extract_strings.py source/localizationen_assets_all.bundle translations/strings_en.json translations/strings_en.csv")
    print(f"  3. Translate the new/changed entries (see {out.relative_to(ROOT)}) into a new batch file")
    print(f"  4. python scripts/apply_translations.py translations/batches/batch_NNNN.py")
    print(f"  5. python scripts/build_distribution.py   # rebuilds bundle and ZIP")


if __name__ == "__main__":
    main()
