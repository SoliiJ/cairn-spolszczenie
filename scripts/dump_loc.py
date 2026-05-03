"""Dump a Unity Localization StringTable from a bundle to JSON."""
import sys, json
import UnityPy
from pathlib import Path

def dump(bundle_path: str, out_path: str):
    env = UnityPy.load(bundle_path)
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception as e:
            print(f"typetree fail: {e}")
            tree = None
        if tree is None:
            try:
                data = obj.read()
                tree = data.read_typetree() if hasattr(data, 'read_typetree') else None
            except Exception as e:
                print(f"obj.read fail: {e}")
                continue
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(tree, f, ensure_ascii=False, indent=2, default=str)
        print(f"Wrote {out_path}")
        # Print top-level keys
        if isinstance(tree, dict):
            print("Top-level keys:", list(tree.keys()))
        return

if __name__ == "__main__":
    dump(sys.argv[1], sys.argv[2])
