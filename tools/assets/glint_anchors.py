#!/usr/bin/env python3
"""Read source alpha to record outer-edge emitter coordinates; never edit images."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
def build(catalog_path=None):
 manifest=json.loads((ROOT/'assets/manifest.json').read_text())
 explicit_catalog=catalog_path is not None
 catalog_path=Path(catalog_path) if catalog_path else ROOT/'build/qa/ecosystem-v125/runtime-catalogue.json'
 if explicit_catalog and not catalog_path.is_file():raise FileNotFoundError(f'Explicit catalogue does not exist: {catalog_path}')
 catalog=json.loads((catalog_path if catalog_path.exists() else ROOT/'data/catalog.json').read_text())['items']
 if not isinstance(catalog,dict) or not catalog:raise ValueError('Catalogue must contain a non-empty items mapping')
 output={}
 for kind,definition in catalog.items():
  if int(definition.get('craft_tier',definition.get('rarity',1)))<4 or 'bag' in definition.get('tags',[]):continue
  entry=manifest['items'].get(kind,{})
  path=ROOT/entry.get('path','missing')
  if not path.is_file() or path.suffix.lower() not in ['.png','.webp']:continue
  image=Image.open(path).convert('RGBA');pixels=np.asarray(image);mask=pixels[:,:,3]>150
  yy,xx=np.where(mask)
  if not len(xx):continue
  bounds=(xx.min(),yy.min(),xx.max(),yy.max());points=[]
  def add(x,y,nx,ny):
   if any((x-p[0]*image.width)**2+(y-p[1]*image.height)**2<(max(image.size)*.015)**2 for p in points):return
   tone=pixels[y,x,:3]/255
   for step in [3,6,12,20]:
    ix=int(np.clip(x-nx*step,0,image.width-1));iy=int(np.clip(y-ny*step,0,image.height-1))
    if mask[iy,ix] and pixels[iy,ix,:3].mean()/255>tone.mean():tone=pixels[iy,ix,:3]/255
   points.append([round(x/image.width,6),round(y/image.height,6),nx,ny,*[round(float(c),4) for c in tone]])
  for x in np.linspace(bounds[0],bounds[2],25).astype(int):
   rows=np.flatnonzero(mask[:,x])
   if len(rows):add(x,int(rows[0]),0,-1);add(x,int(rows[-1]),0,1)
  for y in np.linspace(bounds[1],bounds[3],13).astype(int):
   cols=np.flatnonzero(mask[y,:])
   if len(cols):add(int(cols[0]),y,-1,0);add(int(cols[-1]),y,1,0)
  output[kind]={'path':entry['path'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(image.size),'points':points}
 path=ROOT/'assets/ui/stars/glint-anchors.json';path.write_text(json.dumps(output,ensure_ascii=False,separators=(',',':'))+'\n')
 print(f'{len(output)} high-quality items, source images unchanged')
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--catalog',help='Explicit exported runtime catalogue; source sprites are never modified.')
 build(parser.parse_args().catalog)
