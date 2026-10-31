"""Register generated originals without resizing or editing the source pixels."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT / "tools"))
from privacy import public_source
DOC = ROOT / 'build/qa/wuwa-items-v128'
results = json.loads((DOC / 'generation-results.json').read_text())
spec = json.loads((ROOT / 'data/items/solaris.json').read_text())
sources = {str(s['id']): s for s in json.loads((DOC / 'sources.json').read_text())}
manifest_path = ROOT / 'assets/manifest.json'
manifest = json.loads(manifest_path.read_text())
bounds_path = ROOT / 'assets/generated/alpha-bounds.json'
bounds = json.loads(bounds_path.read_text())
entries = []
for entry in results:
    kind = entry['kind']
    item = spec['new_items'][kind]
    source = Path(entry['source_generated_path'])
    rel = f'assets/items/solaris/{kind}.png'
    target = ROOT / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert source.read_bytes() == target.read_bytes()
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    with Image.open(target) as im:
        assert im.mode == 'RGBA', (kind, im.mode)
        alpha = im.getchannel('A')
        assert alpha.getextrema() == (0, 255), kind
        box = alpha.getbbox()
        assert box is not None
        bounds['res://' + rel] = [box[0], box[1], box[2] - box[0], box[3] - box[1]]
        dimensions = im.size
        visible = alpha.point(lambda a: 255 if a > 16 else 0).getbbox()
    src = sources[str(entry['source_id'])]
    manifest['items'][kind] = {
        'path': rel, 'name': item['name'], 'reference': src['reference_path'],
        'original_reference': src['asset_url'], 'source_page': src['source_page'],
        'angle': 0, 'status': 'generated_reviewed', 'tags': [item['category']],
        'shape': item['shape'], 'generator': 'built_in_image_gen',
        'raw_path': public_source(source), 'sha256': digest,
    }
    entries.append({
        **entry, 'source_generated_path': public_source(source), 'output_path': rel, 'sha256': digest,
        'width': dimensions[0], 'height': dimensions[1],
        'alpha_bounds': bounds['res://' + rel], 'visible_alpha_bounds_16': visible,
        'generated_bytes_preserved': True, 'original_concept': False,
        'identity': '鸣潮原作物品', 'gameplay': '本作改编效果与配方',
        'source_page': src['source_page'], 'original_asset_url': src['asset_url'],
        'reference_hashes': {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in entry['refs']},
    })
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
bounds_path.write_text(json.dumps(bounds, separators=(',', ':')))
(DOC / 'art-manifest.json').write_text(json.dumps({'tool': 'built_in_image_gen', 'count': len(entries), 'entries': entries}, ensure_ascii=False, indent=2))
print(f'Registered {len(entries)} original-identity Q sprites; original RGBA bytes unchanged.')
