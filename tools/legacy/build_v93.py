#!/usr/bin/env python3
"""V92 -> staged public supply and economy, with unchanged item/recipe rules."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRANTS = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 18]
# Entry rounds belong to the shop only. Owned inputs can always be crafted.
ADDITIONS = {
    2: ['weapon_21010104', 'weapon_21010044', 'weapon_21020024', 'weapon_21020044',
        'weapon_21030024', 'weapon_21030074', 'weapon_21040024', 'weapon_21040044',
        'weapon_21050044', 'weapon_21050104',
        'violet', 'rocksteady', 'cyan_heron', 'echo_soulfrayer',
        'aero_coin', 'spectro_coin', 'contract', 'mat_43020031'],
    3: ['discord', 'weapon_21010064', 'weapon_21020074', 'weapon_21020104',
        'weapon_21030044', 'weapon_21030064', 'weapon_21040064', 'weapon_21040074',
        'variation', 'weapon_21050084',
        'flower', 'answer', 'captain_seal', 'puppet', 'medical', 'strategy',
        'mat_42300030', 'mat_41100013', 'echo_bloom', 'echo_spectro',
        'echo_formrender', 'echo_lionarch', 'cool_tea', 'dragon_food'],
    4: ['weapon_21010034', 'weapon_21020094', 'weapon_21030094',
        'weapon_21040094', 'weapon_21050094', 'judgment', 'field_notes'],
    5: ['weapon_21010015', 'weapon_21020015', 'weapon_21030015',
        'weapon_21040015', 'weapon_21050015',
        'feilian', 'thundering', 'bellborne', 'inferno', 'heron'],
    6: ['echo_tianqui', 'echo_hecaton', 'echo_shuxin', 'dreamless'],
    7: ['echo_wankui'],
}
WEAPON = [
    [100, 0, 0, 0], [85, 15, 0, 0], [70, 25, 5, 0], [55, 35, 10, 0],
    [40, 40, 18, 2], [30, 40, 25, 5], [25, 35, 30, 10], [20, 30, 35, 15],
    [20, 25, 35, 20], [20, 20, 35, 25], [20, 20, 35, 25],
]
ECHO = [
    [100, 0, 0, 0], [90, 10, 0, 0], [75, 25, 0, 0], [65, 35, 0, 0],
    [50, 45, 0, 5], [35, 50, 0, 15], [30, 45, 0, 25], [25, 45, 0, 30],
    [20, 45, 0, 35], [20, 40, 0, 40], [20, 40, 0, 40],
]
OTHER = [
    [100, 0, 0, 0], [85, 15, 0, 0], [70, 30, 0, 0], [60, 35, 5, 0],
    [50, 40, 10, 0], [40, 40, 20, 0], [35, 40, 25, 0], [30, 40, 30, 0],
    [25, 40, 35, 0], [25, 35, 40, 0], [25, 35, 40, 0],
]

def main():
    before = json.loads((ROOT / 'data/compat/catalog-v92.json').read_text())
    data = copy.deepcopy(before)
    design = json.loads((ROOT / 'data/compat/design/v92.json').read_text())
    stages = {k: int(data['items'][k]['v75']['shop_round']) for k in design['focused_pool']}
    for rn, kinds in ADDITIONS.items():
        for k in kinds:
            spec = data['items'][k]['v75']
            assert spec['active'] and not spec['craft_only'] and spec['tier'] < 5, k
            stages[k] = max(rn, int(spec['shop_round']))
    design['focused_pool'] = list(stages)
    design['offer_rounds'] = stages
    design['shop'] = {
        'assist_probability': .7,
        'category_tiers': {category: {str(i + 1): [v / 100 for v in row] for i, row in enumerate(rows)}
                           for category, rows in [('weapon', WEAPON), ('echo', ECHO), ('other', OTHER), ('mixed', WEAPON)]},
    }
    design['income_by_round'] = GRANTS
    design['design_version'] = 93
    data['economy']['income_by_round'] = GRANTS
    data['design_version'] = 93
    assert data['items'] == before['items'], 'No speculative blanket balance buff'
    assert data['recipes'] == before['recipes']
    for path, value in [('data/catalog.json', data), ('data/compat/design/v93.json', design)]:
        (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    print(f'V93: {len(stages)} staged direct items; {len(data["recipes"])} unchanged recipes; 11 income grants')

if __name__ == '__main__':
    main()
