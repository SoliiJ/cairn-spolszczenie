"""Apply a Python module of {(table, id): polish_text} into strings_pl.json.

Usage:
    python apply_translations.py translations/batches/batch_NNNN.py
"""
import sys, json, importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "translations" / "strings_pl.json"

def load_batch(path):
    spec = importlib.util.spec_from_file_location("batch", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.PL  # expects dict {(table, id): str}

def main():
    batch_path = Path(sys.argv[1]).resolve()
    pl_dict = load_batch(batch_path)
    rows = json.load(open(TARGET, encoding="utf-8"))
    applied = 0
    for k, v in pl_dict.items():
        matched = False
        for r in rows:
            if (r["table"], r["id"]) == k:
                r["pl"] = v
                applied += 1
                matched = True
        if not matched:
            print(f"  WARN no entry for {k}")
    with open(TARGET, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    total_translated = sum(1 for r in rows if r.get("pl"))
    print(f"applied {applied}; total translated {total_translated}/{len(rows)} ({total_translated/len(rows)*100:.1f}%)")

if __name__ == "__main__":
    main()
