#!/usr/bin/env python3
"""Build an isolated runtime-only staging tree and a verified-source PCK.
No player profiles, credentials, server code, tests, or design documents are copied.
"""
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from pathlib import Path
from release_manifest import ROOT,compute
from privacy import check_paths
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
def files():
 entries=json.loads((ROOT/'data/runtime-files.json').read_text())
 allowed=('scripts/','assets/','data/','addons/release_raw/')
 fixed={'project.godot','main.tscn','export_presets.cfg','CREDITS.md'}
 result=[]
 for rel in entries:
  if '..' in Path(rel).parts or Path(rel).is_absolute() or not (rel in fixed or rel.startswith(allowed)):
   raise ValueError('Invalid runtime path: '+rel)
  path=ROOT/rel
  if not path.is_file():raise ValueError('Missing runtime path: '+rel)
  result.append(path)
 return sorted(set(result))
def stage(destination):
 if destination.exists():raise ValueError('staging destination must be new')
 if json.loads((ROOT/'data/release-hashes.json').read_text())!=compute():raise ValueError('stale release rule manifest')
 check_paths([p.relative_to(ROOT) for p in files()])
 destination.mkdir(parents=True)
 inventory=[]
 for source in files():
  rel=source.relative_to(ROOT);target=destination/rel;target.parent.mkdir(parents=True,exist_ok=True)
  shutil.copy2(source,target)
  inventory.append({'path':str(rel),'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
  imp=source.with_suffix(source.suffix+'.import')
  if imp.exists():
   shutil.copy2(imp,target.with_suffix(target.suffix+'.import'))
   for imported in set(re.findall(r'res://(\.godot/imported/[^"\s]+)',imp.read_text())):
    cache=ROOT/imported;out=destination/imported
    if cache.is_file():
     out.parent.mkdir(parents=True,exist_ok=True)
     if not out.exists():os.link(cache,out)
 (destination.parent/(destination.name+'-manifest.json')).write_text(json.dumps(inventory,indent=2,ensure_ascii=False)+'\n')
 return inventory
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--pack',action='store_true');a=p.parse_args()
 entries=stage(a.stage.resolve());print(f'Staged {len(entries)} files, {sum(x["bytes"] for x in entries)/1024**2:.1f} MiB',flush=True)
 if a.pack:
  with open(a.stage.parent/(a.stage.name+'-import.log'),'w') as log:subprocess.run([GODOT,'--headless','--path',str(a.stage),'--editor','--import'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
  pack=a.stage.parent/'SolarisBrawl-v138.pck'
  with open(a.stage.parent/(a.stage.name+'-export.log'),'w') as log:subprocess.run([GODOT,'--headless','--path',str(a.stage),'--export-pack','macOS',str(pack)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
  for name in ['import','export']:
   log=(a.stage.parent/(a.stage.name+'-'+name+'.log')).read_text()
   if 'SCRIPT ERROR' in log or 'ERROR:' in log:raise RuntimeError('Godot '+name+' reported errors; see log')
  print('Packed:',pack,'bytes:',pack.stat().st_size,flush=True)
