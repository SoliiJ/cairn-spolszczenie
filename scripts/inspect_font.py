"""Inspect a TextMeshPro font asset MonoBehaviour to see which characters it covers."""
import sys, io
import UnityPy

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

POLISH_CHARS = "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"


def inspect(bundle_path: str, name_filter: str = None):
    env = UnityPy.load(bundle_path)
    for obj in env.objects:
        if obj.type.name != "MonoBehaviour":
            continue
        try:
            tree = obj.read_typetree()
        except Exception:
            continue
        if not isinstance(tree, dict):
            continue
        name = tree.get("m_Name", "?")
        if name_filter and name_filter.lower() not in name.lower():
            continue
        # Look for character_table or m_CharacterTable / m_glyphTable
        ct = tree.get("m_CharacterTable") or tree.get("m_characterTable") or tree.get("character_table")
        gt = tree.get("m_GlyphTable") or tree.get("m_glyphTable")
        print(f"=== {name} ===")
        print(f"  AtlasPopulationMode: {tree.get('m_AtlasPopulationMode')}  InternalDynamicOS: {tree.get('InternalDynamicOS')}")
        fb = tree.get('m_FallbackFontAssetTable')
        print(f"  fallbacks: {len(fb) if fb else 0}")
        if ct is not None:
            print(f"  characters: {len(ct)}")
            unicodes = []
            for c in ct:
                u = c.get("m_Unicode") if isinstance(c, dict) else None
                if u is not None:
                    unicodes.append(u)
            uset = set(unicodes)
            missing = [c for c in POLISH_CHARS if ord(c) not in uset]
            print(f"  missing polish chars: {missing}")
            if unicodes:
                print(f"  unicode range: {min(unicodes)}..{max(unicodes)} ({chr(min(unicodes)) if min(unicodes)>=32 else '?'} .. {chr(max(unicodes)) if max(unicodes)<0x10FFFF else '?'})")
        if gt is not None:
            print(f"  glyphs: {len(gt)}")
        print()


if __name__ == "__main__":
    inspect(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
