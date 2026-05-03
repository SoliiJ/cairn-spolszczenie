"""Test that we can modify a localization bundle and write it back with valid result."""
import sys
import UnityPy
from pathlib import Path


def roundtrip(src: str, dst: str, sample_text: str = "Cairn po polsku — test ąęćłńóśżź"):
    env = UnityPy.load(src)
    found = False
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception:
            continue
        if not (isinstance(tree, dict) and "texts" in tree):
            continue
        # Modify the very first key text
        tree["texts"][0]["keys"][0]["text"] = sample_text
        obj.save_typetree(tree)
        found = True
        break
    if not found:
        raise RuntimeError("No MonoBehaviour modified")
    with open(dst, "wb") as f:
        f.write(env.file.save())
    print(f"Wrote {dst}")

    # Re-open and verify
    env2 = UnityPy.load(dst)
    for obj in env2.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        tree = obj.read_typetree()
        if isinstance(tree, dict) and "texts" in tree:
            txt = tree["texts"][0]["keys"][0]["text"]
            print("Read back:", repr(txt))
            assert txt == sample_text, "Round-trip failed"
            print("OK round-trip")
            return
    raise RuntimeError("Verification failed")


if __name__ == "__main__":
    roundtrip(sys.argv[1], sys.argv[2])
