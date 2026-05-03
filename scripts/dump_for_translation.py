"""Dump strings_en.json into chunked text files for translation review."""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
src = json.load(open(ROOT / "translations" / "strings_en.json", encoding="utf-8"))
chunk_size = int(sys.argv[1]) if len(sys.argv) > 1 else 250
out_dir = ROOT / "translations" / "chunks_en"
out_dir.mkdir(parents=True, exist_ok=True)

for i in range(0, len(src), chunk_size):
    chunk = src[i:i+chunk_size]
    out = out_dir / f"chunk_{i:04d}.txt"
    with open(out, "w", encoding="utf-8") as f:
        for s in chunk:
            # Use a stable separator; preserve indices via table/id
            f.write(f"#{s['table']}|{s['id']}\n{s['en']}\n---\n")
    print(f"wrote {out} ({len(chunk)} entries)")
