#!/usr/bin/env python3
"""Build the single local V2 candidate. Never uploads or edits the live feed.

The previous candidate is replaced only after exports and package checks pass.
Intermediate trees are removed after success; compact evidence stays private.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from build import ROOT, GODOT, stage
from build_web import run_godot
from privacy import check_paths, findings

VERSION = '0.2.0'
SEQUENCE = 14105
BASE_ID = 'desktop-v142'


def check_package(output):
    # Godot's official binaries contain public CI/library source locations.
    # Exempt only exact string segments present in that platform's template;
    # game resources, updater helpers and newly introduced strings stay strict.
    templates = Path.home() / 'Library/Application Support/Godot/export_templates/4.7.2.stable'
    native = {
        'Windows/SolarisBrawl/SolarisBrawl.exe': (templates / 'windows_release_x86_64.exe').read_bytes(),
    }
    for target, archive_name, member in [
        ('macOS/索拉里斯大乱斗.app/Contents/MacOS/索拉里斯大乱斗', 'macos.zip', 'macos_template.app/Contents/MacOS/godot_macos_release.universal'),
        ('Web/index.wasm', 'web_nothreads_release.zip', 'godot.wasm'),
    ]:
        with zipfile.ZipFile(templates / archive_name) as bundle:
            native[target] = bundle.read(member)
    strict, inherited = [], {}
    for path in output.rglob('*'):
        if not path.is_file():
            continue
        rel = path.relative_to(output).as_posix()
        if rel not in native:
            strict.append(Path(rel))
            continue
        baseline = set(re.findall(rb'[\x20-\x7e]{12,}', native[rel]))
        count = 0
        for segment in re.findall(rb'[\x20-\x7e]{12,}', path.read_bytes()):
            hit = findings(segment)
            if hit:
                if hit != ['personal-home-path'] or segment not in baseline:
                    raise ValueError('New private metadata in native binary: ' + rel)
                count += 1
        inherited[rel] = count
    check_paths(strict, output)
    return inherited


def configure(runtime):
    path = runtime / 'data/update-channel.json'
    value = json.loads(path.read_text())
    value.update(version=VERSION, sequence=SEQUENCE, base_id=BASE_ID)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    inventory = runtime.parent / (runtime.name + '-manifest.json')
    entries = json.loads(inventory.read_text())
    for row in entries:
        file = runtime / row['path']
        row.update(bytes=file.stat().st_size, sha256=hashlib.sha256(file.read_bytes()).hexdigest())
    inventory.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
    return inventory


def archive(source, target):
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for file in sorted(source.rglob('*')):
            if file.is_file():
                out.write(file, file.relative_to(source.parent).as_posix())


def main():
    private = ROOT / '.local'
    private.mkdir(exist_ok=True)
    logs = private / 'release-audit/V2'
    logs.mkdir(parents=True, exist_ok=True)
    releases = ROOT / 'releases'
    releases.mkdir(exist_ok=True)
    (releases / '.gdignore').touch()
    with tempfile.TemporaryDirectory(prefix='release-build-', dir=private) as tmp:
        work = Path(tmp)
        runtime = work / 'desktop'
        stage(runtime)
        inventory = configure(runtime)
        shutil.copy2(inventory, logs / 'desktop-manifest.json')
        run_godot(['--path', str(runtime), '--editor', '--import'], logs / 'desktop-import.log')
        output = work / 'V2'
        macdir, windir, web = (output / name for name in ('macOS', 'Windows', 'Web'))
        for folder in (macdir, windir, web):
            folder.mkdir(parents=True)
        app = macdir / '索拉里斯大乱斗.app'
        win = windir / 'SolarisBrawl'
        win.mkdir()
        for preset, target in [('macOS', app), ('Windows', win / 'SolarisBrawl.exe')]:
            print('Exporting ' + preset, flush=True)
            run_godot(['--path', str(runtime), '--export-release', preset, str(target)], logs / (preset + '-export.log'))
        # Native updater is built from source, never copied from an old release.
        with (logs / 'helpers.log').open('w') as log:
            subprocess.run(['python3', str(ROOT / 'tools/updater/build.py'), 'build', '--output', str(work / 'helpers')], stdout=log, stderr=subprocess.STDOUT, check=True)
        shutil.copy2(work / 'helpers/macOS/SolarisUpdater', app / 'Contents/MacOS/SolarisUpdater')
        shutil.copy2(work / 'helpers/Windows/SolarisUpdater.exe', win / 'SolarisUpdater.exe')
        for install, exe in [(app, 'Contents/MacOS/索拉里斯大乱斗'), (win, 'SolarisBrawl.exe')]:
            subprocess.run(['python3', str(ROOT / 'tools/updater/build.py'), 'mark', '--install', str(install), '--executable', exe, '--sequence', str(SEQUENCE)], check=True)
        subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        # Check the actual game exported to PCK, outside the source tree.
        for label, pack in [('macOS', app / 'Contents/Resources/索拉里斯大乱斗.pck'), ('Windows', win / 'SolarisBrawl.pck')]:
            run_godot(['--path', str(work), '--main-pack', str(pack), '--script', str(ROOT / 'tests/scenarios/verify_web_pack.gd'), '--', str(inventory), '--desktop'], logs / (label + '-resources.log'))
        # Web keeps the existing lossless silhouette compression and export plugin.
        wr = work / 'web-runtime'
        stage(wr)
        wi = configure(wr)
        print('Exporting Web', flush=True)
        run_godot(['--path', str(ROOT), '--script', 'tools/assets/compress_web_cache.gd', '--', str(wr)], logs / 'web-compress.log')
        run_godot(['--path', str(wr), '--editor', '--import'], logs / 'web-import.log')
        run_godot(['--path', str(wr), '--export-release', 'Web', str(web / 'index.html')], logs / 'web-export.log')
        run_godot(['--path', str(work), '--main-pack', str(web / 'index.pck'), '--script', str(ROOT / 'tests/scenarios/verify_web_pack.gd'), '--', str(wi)], logs / 'web-resources.log')
        for folder in (macdir, windir, web):
            shutil.copy2(ROOT / 'CREDITS.md', folder / 'CREDITS.md')
        (web / '本机试玩.command').write_text('#!/bin/bash\ncd "$(dirname "$0")"\npython3 -m http.server 8000 --bind 127.0.0.1\n')
        (web / '本机试玩.command').chmod(0o755)
        (output / '先看这里.txt').write_text('索拉里斯大乱斗 · V2 最新试玩版\n\nMac：打开 macOS，双击「索拉里斯大乱斗.app」。无需 Godot。\nWindows：打开 Windows/SolarisBrawl，双击 SolarisBrawl.exe；不要拆开同目录文件。\nWeb：启动 Web/本机试玩.command，然后访问 http://127.0.0.1:8000；不能用 file:// 直接打开。\n\n三端使用同一套玩法代码。此目录只保留最新一套三端包。线上发布由独立发布流程完成。\n桌面本地存档沿用原位置。Mac 使用 ad-hoc 签名，未做 Apple 公证。\n')
        inherited = check_package(output)
        (logs / 'template-metadata.json').write_text(json.dumps(inherited, indent=2) + '\n')
        print('Archiving three platforms', flush=True)
        archive(app, macdir / 'SolarisBrawl-V2-macOS-universal.zip')
        archive(win, windir / 'SolarisBrawl-V2-Windows-x86_64.zip')
        archive(web, output / 'SolarisBrawl-V2-Web.zip')
        sums = []
        for file in sorted(output.rglob('*.zip')):
            sums.append(hashlib.sha256(file.read_bytes()).hexdigest() + '  ' + file.relative_to(output).as_posix())
        (output / 'SHA256SUMS.txt').write_text('\n'.join(sums) + '\n')
        report = {'label': 'V2', 'version': VERSION, 'sequence': SEQUENCE, 'base_id': BASE_ID, 'published': False, 'checksums': sums}
        (output / 'build-info.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        shutil.copy2(output / 'build-info.json', logs / 'build-info.json')
        # Keep one latest candidate, while leaving the previous one intact on failure.
        target, previous = releases / 'V2', work / 'previous'
        if target.exists():
            target.rename(previous)
        try:
            output.rename(target)
        except OSError:
            if previous.exists():
                previous.rename(target)
            raise
        print('V2 ready: releases/V2', flush=True)


if __name__ == '__main__':
    main()
