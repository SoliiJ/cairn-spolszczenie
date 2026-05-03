"""Extract all strings from Cairn localization bundle into a JSON
work file used downstream for translation, and CSV for inspection."""
import sys, json, csv
import UnityPy
from pathlib import Path


def load_table(bundle_path: str):
    env = UnityPy.load(bundle_path)
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception:
            continue
        if isinstance(tree, dict) and "texts" in tree:
            return obj, tree
    raise RuntimeError("No localization MonoBehaviour found")


def extract(bundle_path: str, json_out: str, csv_out: str):
    _, tree = load_table(bundle_path)
    rows = []
    for ti, table in enumerate(tree["texts"]):
        for entry in table.get("keys", []):
            rows.append({
                "table": ti,
                "id": entry["id"]["value"],
                "en": entry["text"],
                "pl": "",
            })
    with open(json_out, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    with open(csv_out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["table", "id", "en", "pl"])
        for r in rows:
            w.writerow([r["table"], r["id"], r["en"], r["pl"]])
    print(f"Extracted {len(rows)} strings -> {json_out} / {csv_out}")


if __name__ == "__main__":
    extract(sys.argv[1], sys.argv[2], sys.argv[3])
