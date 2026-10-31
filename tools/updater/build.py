#!/usr/bin/env python3
"""Build the pinned native updater or mark a dedicated release installation.

Only the public key from data/update-channel.json is embedded. No signing key is
read, and Go builds use -trimpath and omit VCS metadata.
"""
from __future__ import annotations
import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/updater"
APP_ID = "game.solarisbrawl.demo"


def marker(install: Path, executable: str, sequence: int) -> None:
    if sequence < 1 or sequence > 2147483647:
        raise SystemExit("invalid sequence")
    if install.is_symlink() or not install.is_dir():
        raise SystemExit("installation must be a dedicated real directory")
    is_mac = (install / "Contents/MacOS").is_dir()
    if is_mac != executable.startswith("Contents/MacOS/"):
        raise SystemExit("executable does not match installation layout")
    marker_name = "Contents/Resources/update-install.json" if is_mac else "update-install.json"
    if is_mac and (install / "update-install.json").exists():
        raise SystemExit("remove obsolete root marker before signing a macOS bundle")
    names = []
    for file in sorted(install.rglob("*")):
        if file.is_symlink():
            raise SystemExit("installation cannot contain symbolic links")
        if file.is_file():
            name = file.relative_to(install).as_posix()
            if name != marker_name:
                names.append(name)
    if executable not in names:
        raise SystemExit("executable must name a regular file inside installation")
    if len(set(name.casefold() for name in names)) != len(names):
        raise SystemExit("installation has case-colliding names")
    payload = dict(schema=1, app_id=APP_ID, sequence=sequence, executable=executable, files=names)
    (install / marker_name).parent.mkdir(parents=True, exist_ok=True)
    (install / marker_name).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def build(output: Path, targets: list[str]) -> None:
    go = shutil.which("go")
    if not go:
        raise SystemExit("Go is required")
    channel = json.loads((ROOT / "data/update-channel.json").read_text())
    public_key = channel["public_key"]
    if not public_key.startswith("-----BEGIN PUBLIC KEY-----") or "PRIVATE" in public_key:
        raise SystemExit("channel must contain only a public signing key")
    encoded = base64.b64encode(public_key.encode()).decode()
    output.mkdir(parents=True, exist_ok=True)
    for target in targets:
        folder = output / target
        folder.mkdir(parents=True, exist_ok=True)
        combinations = [("windows", "amd64", "SolarisUpdater.exe")] if target == "Windows" else [
            ("darwin", "amd64", "SolarisUpdater-amd64"), ("darwin", "arm64", "SolarisUpdater-arm64")]
        for goos, goarch, name in combinations:
            env = dict(os.environ, CGO_ENABLED="0", GOOS=goos, GOARCH=goarch, GOTOOLCHAIN="local")
            ldflags = f"-s -w -X=main.publicKeyB64={encoded}"
            if goos == "windows":
                ldflags += " -H=windowsgui"
            subprocess.run([go, "build", "-trimpath", "-buildvcs=false", "-ldflags",
                            ldflags, "-o", str(folder / name), "."],
                           cwd=SOURCE, env=env, check=True)
        if target == "macOS":
            lipo = shutil.which("lipo")
            if not lipo:
                raise SystemExit("lipo is required to make the universal macOS helper")
            subprocess.run([lipo, "-create", str(folder / "SolarisUpdater-amd64"),
                            str(folder / "SolarisUpdater-arm64"), "-output", str(folder / "SolarisUpdater")], check=True)
            (folder / "SolarisUpdater").chmod(0o755)
            (folder / "SolarisUpdater-amd64").unlink()
            (folder / "SolarisUpdater-arm64").unlink()
        print(f"Built {target} helper")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    b = commands.add_parser("build")
    b.add_argument("--output", type=Path, required=True)
    b.add_argument("--target", action="append", choices=["Windows", "macOS"])
    m = commands.add_parser("mark")
    m.add_argument("--install", type=Path, required=True)
    m.add_argument("--executable", required=True)
    m.add_argument("--sequence", type=int, required=True)
    args = parser.parse_args()
    if args.command == "build":
        build(args.output.resolve(), args.target or ["Windows", "macOS"])
    else:
        marker(args.install.resolve(), args.executable, args.sequence)


if __name__ == "__main__":
    main()
