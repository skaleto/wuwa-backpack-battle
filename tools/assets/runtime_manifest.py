#!/usr/bin/env python3
"""Generate the explicit runtime file inventory from registries and bounded roots."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'data/runtime-files.json'
def collect():
    selected={'project.godot','main.tscn','export_presets.cfg','CREDITS.md'}
    scripts=list((ROOT/'scripts').rglob('*.gd'))+list((ROOT/'scripts').rglob('*.gdshader'))
    selected.update(str(p.relative_to(ROOT)) for p in scripts)
    selected.update(str(p.relative_to(ROOT)) for p in (ROOT/'addons/release_raw').iterdir() if p.is_file() and p.suffix!='.uid')
    manifest=json.loads((ROOT/'assets/manifest.json').read_text())
    selected.add('assets/manifest.json')
    for group in ['items','characters','ui','bags']:
        for entry in manifest[group].values():
            if entry.get('path'):selected.add(entry['path'].removeprefix('res://'))
    # Explicit dynamic loaders: audio event families, VFX sprites, skin variants,
    # and cached descriptors. This is deliberately not a traversal of assets/.
    for group in ['assets/audio','assets/vfx','assets/generated','assets/fonts',
                  'assets/ui/recruitment','assets/ui/bags-patchwork','assets/ui/bags-trials',
                  'assets/ui/bags-soft','assets/ui/bags-shaped','assets/ui/bags-storybook']:
        for p in (ROOT/group).rglob('*'):
            if p.is_file() and p.suffix in {'.png','.jpg','.webp','.wav','.ogg','.ttf','.json','.bin','.txt','.md'}:
                selected.add(str(p.relative_to(ROOT)))
    # Exact published snapshots are required by Storage's legacy matcher.
    selected.update(str(p.relative_to(ROOT)) for p in (ROOT/'data/compat').glob('catalog*.json'))
    for p in scripts:
        selected.update(re.findall(r'''res://((?:assets|data)/[^\s"']+\.(?:png|jpg|webp|json|ttf|sha256|wav|ogg))''',p.read_text()))
    # Atlas descriptors have a second-level texture dependency.
    for rel in list(selected):
        if rel.endswith('.atlas.json'):
            selected.add(json.loads((ROOT/rel).read_text())['atlas'].removeprefix('res://'))
    missing=[p for p in sorted(selected) if not (ROOT/p).is_file()]
    if missing:raise ValueError('Missing runtime files: '+', '.join(missing))
    return sorted(selected)
if __name__=='__main__':
    OUT.write_text(json.dumps(collect(),indent=2)+'\n')
    print('Registered runtime files:',len(json.loads(OUT.read_text())))
