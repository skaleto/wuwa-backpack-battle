#!/usr/bin/env python3
"""Apply the approved V83 patch to the exact V82 catalogue; no image or shape changes."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
c=json.loads((ROOT/'data/compat/catalog-v82.json').read_text())
p=json.loads((ROOT/'data/compat/design/v83.json').read_text())
for kind,price in p['bag_prices'].items(): c['items'][kind]['price']=price
for kind,patch in p['characters'].items():
    ch=c['characters'][kind]; n=patch['charge']
    ch['v60_opening']=[{'type':'charge','value':n}]
    ch['passive']=f'开场充能 +{n}'
    ch['v60_traits'][0]=['开场',f'充能 +{n}']
    ch['adaptation_summary']=f'本作改编：开场充能 +{n}'
    ch['starter_supply']=patch['starter_supply']
c['design_version']=83
c['economy']=p['economy']
(ROOT/'data/catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
