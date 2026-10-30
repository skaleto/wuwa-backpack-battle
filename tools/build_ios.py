#!/usr/bin/env python3
"""Export an isolated, losslessly packed iPhone Xcode project.

Signing/build/install are separate Xcode steps. This does not publish to Apple,
copy player saves, or modify desktop/Web project settings.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from build import ROOT, stage
from build_web import run_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--team-id', required=True)
    parser.add_argument('--bundle-id', default='game.solarisbrawl.demo')
    args = parser.parse_args()
    staging, output = args.stage.resolve(), args.output.resolve()
    if not re.fullmatch(r'[A-Z0-9]{10}', args.team_id):
        parser.error('team-id must contain 10 uppercase letters/digits')
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', args.bundle_id):
        parser.error('invalid bundle-id')
    if staging.exists() or output.exists():
        parser.error('stage and output must be new directories')
    if staging == output or staging in output.parents or output in staging.parents:
        parser.error('stage and output must be separate trees')
    # Godot polls Apple devices during export. Incomplete Xcode setup can leave
    # that background poll waiting indefinitely for privileged installation.
    try:
        setup = subprocess.run(['xcodebuild', '-checkFirstLaunchStatus'],
                               capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        parser.error('Cannot check Xcode setup: ' + str(error))
    if setup.returncode:
        parser.error('Complete `sudo xcodebuild -runFirstLaunch` on this Mac first; '
                     'then verify iOS platform support in Xcode Settings > Components.')
    entries = stage(staging)
    output.mkdir(parents=True)
    logs = output.parent / (output.name + '-logs')
    logs.mkdir(exist_ok=True)

    # iPhone launch options live only in the exported staging project.
    project = staging / 'project.godot'
    text = project.read_text().replace('[application]',
        '[application]\nconfig/icon="res://assets/ui/base/glyph_ghost.png"').replace(
        'window/stretch/mode="canvas_items"',
        'window/stretch/mode="canvas_items"\n'
        'window/handheld/orientation=0')
    text += '\n[input_devices]\npointing/emulate_mouse_from_touch=true\n'
    project.write_text(text)
    exporter = staging / 'addons/release_raw/raw_export.gd'
    original = exporter.read_text()
    assert 'if "web" in _features and' in original
    exporter.write_text(original.replace('if "web" in _features and',
                                        'if ("web" in _features or "ios" in _features) and'))
    presets = staging / 'export_presets.cfg'
    presets.write_text(presets.read_text() + f'''
[preset.3]
name="iOS"
platform="iOS"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.bin,*.sha256,*.md,*.txt"
exclude_filter="build/*,docs/*,art_sources/*,tests/*,tools/*,services/*,addons/*,.git/*"
export_path=""
script_export_mode=0

[preset.3.options]
application/app_store_team_id="{args.team_id}"
application/bundle_identifier="{args.bundle_id}"
application/export_project_only=true
application/code_sign_identity_debug="Apple Development"
application/code_sign_identity_release="Apple Development"
application/short_version="0.1.0"
application/version="138.1"
application/min_ios_version="15.0"
application/targeted_device_family=0
architectures/arm64=true
entitlements/game_center=false
''')
    run_godot(['--path', str(ROOT), '--script',
               'tools/assets/compress_web_cache.gd', '--', str(staging)], logs/'compress.log')
    run_godot(['--path', str(staging), '--editor', '--import'], logs/'import.log')
    run_godot(['--path', str(staging), '--export-release', 'iOS',
               str(output/'SolarisBrawl.zip')], logs/'export.log')
    allowed_changes = {'project.godot', 'export_presets.cfg', 'addons/release_raw/raw_export.gd'}
    changed = []
    for entry in entries:
        rel = entry['path']
        if hashlib.sha256((staging/rel).read_bytes()).hexdigest() != entry['sha256']:
            if rel not in allowed_changes and not rel.startswith('assets/generated/silhouettes/'):
                raise RuntimeError('Unexpected staged change: ' + rel)
            changed.append(rel)
    packs = list(output.rglob('*.pck'))
    if len(packs) != 1:
        raise RuntimeError('Expected one exported resource pack')
    empty = logs/'empty'
    empty.mkdir(exist_ok=True)
    run_godot(['--path', str(empty), '--main-pack', str(packs[0]), '--script',
               str(ROOT/'tests/scenarios/verify_web_pack.gd'), '--',
               str(staging.parent/(staging.name+'-manifest.json'))], logs/'assets-verify.log')
    report = {'bundle_id': args.bundle_id, 'pack_bytes': packs[0].stat().st_size,
              'pack_sha256': hashlib.sha256(packs[0].read_bytes()).hexdigest(),
              'staged_changes': changed, 'xcode_project_only': True,
              'signed': False, 'device_tested': False}
    (logs/'build.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'staged_changes'}, indent=2))


if __name__ == '__main__':
    main()
