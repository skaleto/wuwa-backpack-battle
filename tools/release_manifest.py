#!/usr/bin/env python3
"""Published rule fingerprints, stable across the mechanical V138 layout move."""
from pathlib import Path
import argparse, hashlib, json, re
ROOT = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((ROOT/'tools/maintenance/layout-map.json').read_text())
# Only path spellings changed. Reverse those spellings before applying the
# original published formula; real code/data edits still change fingerprints.
REVERSE = {v:k for k,v in LAYOUT.items()}
TOKENS = re.compile('|'.join(re.escape(k) for k in sorted(REVERSE,key=len,reverse=True)))
def published_text(path):
    text=(ROOT/LAYOUT.get(path,path)).read_text()
    return TOKENS.sub(lambda m: REVERSE[m.group()],text)
def digest(text):
    value=hashlib.sha256(text.encode()).hexdigest()
    aliases=json.loads((ROOT/'data/compat/privacy-fingerprints.json').read_text())
    return aliases.get(value,value)
def compute():
    read=published_text
    v={}
    v['common_hash']=digest(read('assets/catalog.json'))
    v['v114_hash']=digest(read('assets/catalog.json')+read('scripts/specialty_catalog_v114.gd'))
    v['v116_hash']=digest(v['v114_hash']+''.join(read('scripts/'+p+'.gd') for p in ['leader_catalog_v115','crew_abilities_v115','recruitment_v115','space_catalog_v116','pocket_rules'])+'resonance-v116')
    for ver,prev,path in [(124,116,'strategy'),(125,124,'ecosystem'),(127,125,'families'),(128,127,'wuwa-items')]:
        v[f'v{ver}_hash']=digest(v[f'v{prev}_hash']+read(f'assets/design/{path}-v{ver}.json')+f'resonance-v{ver}')
    v['catalogue_hash']=digest(v['v128_hash']+read('assets/design/pockets-v129.json')+'pockets-v129')
    return v
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    path=ROOT/'data/release-hashes.json';values=compute()
    if a.check:
        if json.loads(path.read_text())!=values:raise SystemExit('Rules changed: review and regenerate release hashes before publishing a new online pool.')
    else:path.write_text(json.dumps(values,indent=2)+'\n')
    print('Release catalogue:',values['catalogue_hash'])
