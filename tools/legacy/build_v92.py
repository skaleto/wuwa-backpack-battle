#!/usr/bin/env python3
"""Published V88 -> permanent provisions and authored quality-bounded stars.

No perimeter generation. Prices, shapes, effect values and recipes stay exact.
The runtime consumes catalog.json only; this file is the deterministic authoring step.
"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
LIMITS = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5}
LAYOUTS = {
    'w_pistol': [[0, 1], [1, 1]],
    'w_rectifier': [[2, 0], [0, 2]],
    'contract': [[1, 0], [1, 1]],
    'aero_coin': [[0, 1], [0, 2]],
    'electro_coin': [[1, 0], [-2, 0]],
    'whiff': [[0, -1], [0, -2]],
    'turtle': [[0, -1], [0, 1]],
    'weapon_21020011': [[0, 1], [1, 1]],
    'weapon_21020012': [[0, 1], [1, 1]],
    'weapon_21050011': [[2, 0], [0, 2]],
    'wuka': [[0, -1], [1, 0]],
    'glasses': [[0, 1], [1, 2]],
    'spectro_coin': [[1, 0], [-2, 0]],
    'echo_vanguard': [[0, -2], [0, 1]],
    'echo_butterfly': [[0, 1], [1, 1]],
    'contract_echo': [[1, 0], [1, 1], [-2, 0]],
    'echo_bloom': [[1, 0], [1, 1]],
    # Room for two distinct echo sources and two weapon beneficiaries.
    'echo_tianqui': [[0, 3], [2, 3], [0, 2], [2, 2]],
    # Two weapon sources, healing source and a flexible fourth link.
    'echo_hecaton': [[0, -1], [2, -1], [0, 2], [2, 2]],
}

def migrate(value):
    if isinstance(value, dict):
        return {k: migrate(v) for k, v in value.items()}
    if isinstance(value, list):
        return [migrate(v) for v in value]
    if isinstance(value, str):
        return {'consumable': 'provision', 'consume': 'supply'}.get(value, value.replace('，随后饮尽。', '，每场一次。'))
    return value

def main():
    before = json.loads((ROOT / 'data/compat/catalog-v88.json').read_text())
    data = migrate(before)
    provisions = [k for k, d in before['items'].items() if 'consumable' in d['tags']]
    for kind, stars in LAYOUTS.items():
        d = data['items'][kind]
        d['stars'] = stars
        if 'v75' in d:
            d['v75']['stars'] = stars
    spec = data['items']['cool_tea']['v75']['material_effect']
    spec['notifies_supply'] = spec.pop('consumed')
    for kind, d in data['items'].items():
        stars = [tuple(p) for p in d['stars']]
        assert len(stars) <= LIMITS.get(d['rarity'], 5), kind
        assert len(stars) == len(set(stars)), kind
        assert not set(stars).intersection(map(tuple, d['shape'])), kind
        for field in ['price', 'shape', 'damage', 'cooldown', 'stamina']:
            assert d.get(field) == before['items'][kind].get(field), (kind, field)
    assert data['recipes'] == before['recipes']
    data['design_version'] = 92
    (ROOT / 'data/catalog.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    review = migrate(json.loads((ROOT / 'data/compat/design/v88.json').read_text()))
    review.update({'star_limits': LIMITS, 'provisions': provisions, 'layouts': LAYOUTS,
              'changes': {k: {'name': data['items'][k]['name'], 'quality': data['items'][k]['rarity'],
                              'before': before['items'][k]['stars'], 'after': stars} for k, stars in LAYOUTS.items()}})
    review['items'] = {k: d['v75'] for k, d in data['items'].items() if 'v75' in d}
    for kind in review.get('cards', {}):
        review['cards'][kind]['stars'] = data['items'][kind]['stars']
        review['cards'][kind]['profile'] = data['items'][kind]['v75']
    (ROOT / 'data/compat/design/v92.json').write_text(json.dumps(review, ensure_ascii=False, indent=2) + '\n')
    print(f'V92: {len(provisions)} permanent provisions; {len(LAYOUTS)} authored star layouts; unchanged prices and recipes')

if __name__ == '__main__':
    main()
