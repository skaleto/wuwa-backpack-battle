#!/usr/bin/env python3
"""Export a lossless, runtime-only Web build from a fresh isolated staging tree.

Original art, audio, rules and compatibility snapshots are not rewritten.
Only staged silhouette files are compressed; the Web export omits redundant
imported image copies that the game never loads through ResourceLoader.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

from build import GODOT, ROOT, stage


def run_godot(args, log):
    with log.open('w') as output:
        subprocess.run([GODOT, '--headless', *args], stdout=output,
                       stderr=subprocess.STDOUT, check=True, timeout=600)
    if re.search(r'SCRIPT ERROR|^ERROR:', log.read_text(), re.M):
        raise RuntimeError(f'Godot reported errors; see {log}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    staging, output = args.stage.resolve(), args.output.resolve()
    if staging.exists() or output.exists():
        parser.error('stage and output must both be new directories')
    if staging in output.parents or output in staging.parents or staging == output:
        parser.error('stage and output must be separate trees')
    entries = stage(staging)
    output.mkdir(parents=True)
    logs = output.parent / (output.name + '-logs')
    logs.mkdir(exist_ok=True)
    run_godot(['--path', str(ROOT), '--script',
               'tools/assets/compress_web_cache.gd', '--', str(staging)], logs/'compress.log')
    run_godot(['--path', str(staging), '--editor', '--import'], logs/'import.log')
    run_godot(['--path', str(staging), '--export-release', 'Web',
               str(output/'index.html')], logs/'export.log')
    empty = logs/'empty'
    empty.mkdir(exist_ok=True)
    run_godot(['--path', str(empty), '--main-pack', str(output/'index.pck'),
               '--script', str(ROOT/'tests/scenarios/verify_web_pack.gd'), '--',
               str(staging.parent/(staging.name+'-manifest.json'))], logs/'assets-verify.log')
    # Assert the entire staging contract: compression is the only source-byte
    # difference. Compression round-trips are checked inside the Godot tool.
    changed = []
    for entry in entries:
        rel = entry['path']
        actual = hashlib.sha256((staging/rel).read_bytes()).hexdigest()
        if actual != entry['sha256']:
            if not rel.startswith('assets/generated/silhouettes/') or not rel.endswith('.bin'):
                raise RuntimeError('Unexpected source-byte change: ' + rel)
            changed.append(rel)
    shutil.copy2(ROOT/'CREDITS.md', output/'CREDITS.md')
    shutil.copy2(ROOT/'docs/release/three-platform.md', output/'README.md')
    shutil.copy2(ROOT/'docs/release/web-size.md', output/'web-size.md')
    archive = output.parent/(output.name+'.zip')
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(output.iterdir()):
            bundle.write(path, path.name)
    report = {'compressed_caches': len(changed), 'source_bytes_preserved': True,
              'files': {p.name: p.stat().st_size for p in sorted(output.iterdir())},
              'zip_bytes': archive.stat().st_size,
              'zip_sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
    (logs/'build.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
