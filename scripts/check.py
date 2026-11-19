#!/usr/bin/env python3
"""Run Lua 5.1 syntax and lifecycle checks; validate the installation contract."""
import argparse
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

from package import ADDON, ROOT, build, metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lupa", action="store_true", help="use optional Python lupa.lua51 instead of a Lua CLI")
    args = parser.parse_args()
    os.chdir(ROOT)
    version, files = metadata()
    if args.lupa:
        from lupa.lua51 import LuaRuntime
        lua = LuaRuntime()
        assert lua.eval("_VERSION") == "Lua 5.1"
        run = lambda source: lua.execute(source)
    else:
        command = shutil.which("lua5.1") or shutil.which("lua")
        if not command:
            raise SystemExit("Install Lua 5.1, or pip install lupa and use --lupa.")
        def run(source):
            subprocess.run([command, "-e", source], check=True)
        run('assert(_VERSION == "Lua 5.1", "Tests require Lua 5.1")')
    for name in files:
        run(f"assert(loadfile('addon/MetalWars/{name}'))")
    for path in sorted((ROOT / "tests").glob("test_*.lua")):
        run(f"dofile('tests/{path.name}')")
    archive = build(site=True)
    with zipfile.ZipFile(archive) as package:
        paths = set(package.namelist())
        expected = {"MetalWars/" + name for name in files + ["MetalWars.toc", "INSTALL.txt", "LICENSE.txt"]}
        assert paths == expected, "Install archive contains unexpected/missing files"
        assert package.read("MetalWars/MetalWars.toc") == (ADDON / "MetalWars.toc").read_bytes()
    first = archive.read_bytes()
    assert build().read_bytes() == first, "Identical source must produce an identical ZIP"
    page = (ROOT / "_site" / "index.html").read_text(encoding="utf-8")
    assert "downloads/MetalWars-latest.zip" in page
    assert f"v{version}" in page, "Download page version is stale"
    assert (ROOT / "_site/downloads/MetalWars-latest.zip").read_bytes() == first
    print(f"Lua syntax, addon tests, deterministic package and download contract passed ({version}).")


if __name__ == "__main__":
    main()
