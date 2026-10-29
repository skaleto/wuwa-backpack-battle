"""Read alpha geometry only. Never rewrites source pixels."""
from pathlib import Path
import json
from PIL import Image
root=Path(__file__).resolve().parents[2]
manifest=json.loads((root/'assets/manifest.json').read_text())
paths={e['path'] for group in ['ui','items','characters','bags'] for e in manifest[group].values() if 'path' in e}
paths.add('assets/ui/ability-draft/ability-icons.png')
paths.add('assets/ui/abilities/ability-icons.png')
out={}
for path in sorted(paths):
 file=root/path.removeprefix('res://')
 if path.endswith(".atlas.json"):
  metadata=json.loads(file.read_text())
  atlas=root/metadata["atlas"].removeprefix("res://")
  x,y,w,h=metadata["region"]
  source=Image.open(atlas).crop((x,y,x+w,y+h))
 else:source=Image.open(file)
 with source as img:
  a=img.convert('RGBA').getchannel('A')
  if '/ui' in path or '/characters/' in path:a=a.point(lambda x:255 if x>20 else 0)
  box=a.getbbox() or (0,0,0,0)
  out['res://'+path.removeprefix('res://')]=[box[0],box[1],box[2]-box[0],box[3]-box[1]]
(root/'assets/generated/alpha-bounds.json').write_text(json.dumps(out,separators=(',',':')))
print('cached bounds',len(out))
