"""Build the full distribution: rebuild bundles, copy payload into installer/payload,
verify hashes, then ZIP everything as Cairn-Spolszczenie-<date>.zip in dist/."""
import json, hashlib, shutil, sys, zipfile, datetime
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SRC_BUILD = ROOT / "build"
INSTALLER = ROOT / "installer"
PAYLOAD = INSTALLER / "payload"
DIST = ROOT / "dist"

BUNDLES = [
    "localizationen_assets_all.bundle",
    "dynamicfontsen_assets_all.bundle",
]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def run(cmd):
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def main():
    print("== Rebuild bundles ==")
    run([sys.executable, str(ROOT / "scripts" / "build_pl_bundle.py")])
    run([sys.executable, str(ROOT / "scripts" / "build_pl_fonts.py")])

    print("\n== Stage payload ==")
    PAYLOAD.mkdir(parents=True, exist_ok=True)
    info = {"builtAt": datetime.datetime.now().isoformat(timespec="seconds"), "bundles": []}
    for name in BUNDLES:
        src = SRC_BUILD / name
        dst = PAYLOAD / name
        if not src.exists():
            raise SystemExit(f"missing built bundle: {src}")
        shutil.copy2(src, dst)
        h = sha256(dst)
        info["bundles"].append({"name": name, "sha256": h, "size": dst.stat().st_size})
        print(f"  payload/{name}  size={dst.stat().st_size}  sha256={h[:16]}...")
    (PAYLOAD / "build-info.json").write_text(json.dumps(info, indent=2), encoding="utf-8")

    print("\n== Coverage report ==")
    rows = json.load(open(ROOT / "translations" / "strings_pl.json", encoding="utf-8"))
    translated = sum(1 for r in rows if r.get("pl", "").strip())
    total = len(rows)
    print(f"  translated {translated}/{total} ({translated/total*100:.1f}%)")
    coverage = {"translated": translated, "total": total, "percent": round(translated/total*100, 2)}
    (PAYLOAD / "coverage.json").write_text(json.dumps(coverage, indent=2), encoding="utf-8")

    print("\n== Build ZIP ==")
    DIST.mkdir(parents=True, exist_ok=True)
    today = datetime.date.today().strftime("%Y%m%d")
    zip_path = DIST / f"Cairn-Spolszczenie-{today}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for f in INSTALLER.rglob("*"):
            if f.is_file():
                arcname = "Cairn-Spolszczenie/" + f.relative_to(INSTALLER).as_posix()
                zf.write(f, arcname)
    size_mb = zip_path.stat().st_size / 1024 / 1024
    print(f"  -> {zip_path}  ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
