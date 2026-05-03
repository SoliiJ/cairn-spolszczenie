"""Build the Polish-friendly font bundle by switching TMP font assets to dynamic atlas mode.

The bundled Boxed-Bold/DemiBold/DemiBoldItalic/RegularItalic and LiberationSans TTFs already
contain glyphs for all Polish characters (ą ć ę ł ń ó ś ź ż and capitals). The shipped SDF
atlases are static and only carry 102 ASCII-range glyphs. By flipping the TextMeshPro font
asset to dynamic atlas mode, TMP will rasterize the missing Polish glyphs at runtime from the
embedded TTF source.

Reads:
  - source/dynamicfontsen_assets_all.bundle
Produces:
  - build/dynamicfontsen_assets_all.bundle
"""
import sys
from pathlib import Path
import UnityPy

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "source" / "dynamicfontsen_assets_all.bundle"
OUT = ROOT / "build" / "dynamicfontsen_assets_all.bundle"

# TMP atlas population modes:
DYNAMIC = 1


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    env = UnityPy.load(str(SRC))
    modified = 0
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception:
            continue
        if not isinstance(tree, dict):
            continue
        if "m_AtlasPopulationMode" not in tree:
            continue
        old = tree.get("m_AtlasPopulationMode")
        if old == DYNAMIC:
            continue
        tree["m_AtlasPopulationMode"] = DYNAMIC
        # Make sure dynamic data isn't cleared on build
        if "m_ClearDynamicDataOnBuild" in tree:
            tree["m_ClearDynamicDataOnBuild"] = 0
        obj.save_typetree(tree)
        print(f"  {tree.get('m_Name')}: AtlasPopulationMode {old} -> {DYNAMIC}")
        modified += 1
    with open(OUT, "wb") as f:
        f.write(env.file.save(packer="lz4"))
    print(f"modified {modified} font assets -> {OUT}")


if __name__ == "__main__":
    main()
