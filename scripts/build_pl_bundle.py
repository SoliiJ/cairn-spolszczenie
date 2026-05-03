"""Build the Polish localization bundle.

Reads:
  - source/localizationen_assets_all.bundle  (English source)
  - translations/strings_pl.json             (id -> Polish text)

Produces:
  - build/localizationen_assets_all.bundle   (English bundle, but contents replaced with Polish)

Strategy: replace contents of the English bundle with Polish text. The game
will load it whenever the user has English selected (default or explicit).
The structural layout (id list / table flags) is preserved exactly.
"""
import sys, json
from pathlib import Path
import UnityPy

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "source" / "localizationen_assets_all.bundle"
PL = ROOT / "translations" / "strings_pl.json"
OUT = ROOT / "build" / "localizationen_assets_all.bundle"


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(PL, encoding="utf-8") as f:
        rows = json.load(f)
    pl_map = {(r["table"], r["id"]): r["pl"] for r in rows if r.get("pl")}
    print(f"loaded {len(pl_map)} Polish strings out of {len(rows)} total")

    env = UnityPy.load(str(SRC))
    modified = 0
    fallback = 0
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
                key = (ti, entry["id"]["value"])
                if key in pl_map and pl_map[key].strip():
                    entry["text"] = pl_map[key]
                    modified += 1
                else:
                    fallback += 1
        obj.save_typetree(tree)
        break
    with open(OUT, "wb") as f:
        f.write(env.file.save(packer="lz4"))
    print(f"replaced {modified} strings, {fallback} kept original (no Polish)")
    print(f"wrote {OUT}  ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
