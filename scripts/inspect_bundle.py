"""Inspect a Unity Addressables bundle: list all objects, their types and names."""
import sys
import UnityPy
from pathlib import Path

def inspect(bundle_path: str):
    env = UnityPy.load(bundle_path)
    print(f"=== {Path(bundle_path).name} ===")
    types = {}
    for obj in env.objects:
        types[obj.type.name] = types.get(obj.type.name, 0) + 1
    print("Type counts:")
    for t, c in sorted(types.items(), key=lambda x: -x[1]):
        print(f"  {t}: {c}")

    print("\nObjects (first 200):")
    for i, obj in enumerate(env.objects[:200]):
        try:
            data = obj.read()
            name = getattr(data, 'm_Name', None) or getattr(data, 'name', None) or '<no-name>'
        except Exception as e:
            name = f'<read-error: {e}>'
        print(f"  [{i}] {obj.type.name}  path_id={obj.path_id}  name={name!r}")

if __name__ == "__main__":
    inspect(sys.argv[1])
