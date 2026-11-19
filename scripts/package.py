#!/usr/bin/env python3
"""Build an installable, deterministic addon ZIP and optionally the Pages site."""
import argparse
import hashlib
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon" / "MetalWars"


def metadata():
    toc = (ADDON / "MetalWars.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.M)
    if not version:
        raise SystemExit("MetalWars.toc must contain a semantic Version.")
    files = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    for name in files:
        path = ADDON / name
        if path.parent != ADDON or not path.is_file() or path.is_symlink():
            raise SystemExit(f"Invalid or missing TOC file: {name}")
    return version.group(1), files


def build(site=False):
    version, files = metadata()
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    archive = dist / f"MetalWars-{version}.zip"
    contents = {name: (ADDON / name).read_bytes() for name in files + ["MetalWars.toc", "INSTALL.txt"]}
    contents["LICENSE.txt"] = (ROOT / "LICENSE").read_bytes()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for name, data in sorted(contents.items()):
            entry = zipfile.ZipInfo("MetalWars/" + name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            output.writestr(entry, data, compresslevel=9)
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None or "MetalWars/MetalWars.toc" not in check.namelist():
            raise SystemExit("Invalid addon package")
    latest = dist / "MetalWars-latest.zip"
    shutil.copyfile(archive, latest)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    sums = dist / "SHA256SUMS"
    sums.write_text(f"{checksum}  {archive.name}\n{checksum}  {latest.name}\n", encoding="utf-8")
    if site:
        target = ROOT / "_site"
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(ROOT / "docs", target)
        downloads = target / "downloads"
        downloads.mkdir(exist_ok=True)
        for path in (archive, latest, sums):
            shutil.copyfile(path, downloads / path.name)
    print(f"Built {archive.relative_to(ROOT)} ({archive.stat().st_size:,} bytes)")
    print(f"SHA-256 {checksum}")
    if site:
        print("Pages site: _site/ (includes install ZIPs and SHA256SUMS)")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", action="store_true", help="also build the GitHub Pages site")
    args = parser.parse_args()
    build(args.site)
