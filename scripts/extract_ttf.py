"""Extract Font assets (TTF/OTF) from a bundle to disk."""
import sys
from pathlib import Path
import UnityPy


def extract(bundle_path: str, out_dir: str):
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    env = UnityPy.load(bundle_path)
    for obj in env.objects:
        if obj.type.name != "Font":
            continue
        try:
            data = obj.read()
        except Exception as e:
            print(f"read fail: {e}")
            continue
        name = getattr(data, "m_Name", None) or "font"
        font_bytes = getattr(data, "m_FontData", None)
        if font_bytes is None:
            tree = obj.read_typetree()
            font_bytes = tree.get("m_FontData")
        if font_bytes:
            ext = "ttf"
            if isinstance(font_bytes, (bytes, bytearray)) and bytes(font_bytes)[:4] == b"OTTO":
                ext = "otf"
            out_path = Path(out_dir) / f"{name}.{ext}"
            with open(out_path, "wb") as f:
                f.write(bytes(font_bytes))
            print(f"  wrote {out_path}  ({len(font_bytes)} bytes)")
        else:
            print(f"  no font data for {name}")


if __name__ == "__main__":
    extract(sys.argv[1], sys.argv[2])
