#!/usr/bin/env python3
"""Summarize acquired runs separately from controlled fixtures; never infer player win rate."""
import collections
import csv
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/qa/gameplay-v93/reports'
load = lambda p: json.loads((ROOT / p).read_text())
catalog = load('data/catalog.json')
items = catalog['items']
design = load('data/compat/design/v93.json')

def summary(path):
    report = load(path)
    runs = report['samples']
    rounds = [r for s in runs for r in s['rounds']]
    graduates = []
    for s in runs:
        graduation = [r['round'] for r in s['rounds'] if any(items[i['kind']]['rarity'] == 5 for i in r['items'])]
        if graduation:
            graduates.append({'leader': s['leader'], 'seed': s['seed'], 'route_bias': s['route'],
                              'first_equipped_round': min(graduation),
                              'battles_including_graduation': len([r for r in s['rounds'] if r['round'] >= min(graduation)])})
    return {
        'scope': report['scope'], 'checks': report['checks'], 'failures': report['failures'],
        'runs': len(runs), 'battles': len(rounds), 'mean_battles': statistics.mean(len(s['rounds']) for s in runs),
        'run_lengths': dict(collections.Counter(len(s['rounds']) for s in runs)),
        'max_chain_depths': dict(collections.Counter(s['max_lineage_depth'] for s in runs)),
        'first_craft_rounds': dict(collections.Counter(s['first_fusion'] for s in runs)),
        'runs_with_quality5_equipped': len(graduates), 'graduations': graduates,
        'unique_acquisition_hashes': len({s['acquisition_hash'] for s in runs}),
        'rounds': [{
            'round': n, 'samples': len(rs), 'mean_unspent': statistics.mean(r['gold'] for r in rs),
            'mean_items': statistics.mean(len(r['items']) for r in rs),
            'mean_duration': statistics.mean(r['duration'] for r in rs),
            'mean_bonds': statistics.mean(r['bonds'] for r in rs),
            'mean_star_events': statistics.mean(r['events'][0].get('star_trigger', 0) for r in rs),
        } for n in range(1, 12) if (rs := [r for r in rounds if r['round'] == n])],
    }

def main():
    report = {'catalogue_hash': hashlib.sha256((ROOT/'data/catalog.json').read_bytes()).hexdigest(),
              'before_focused': summary('build/qa/review-v92-progression/focused-ui-match-playthrough.json'),
              'after_focused': summary('tests/fixtures/data/gameplay-v93/reports/focused-ui-match-playthrough.json')}
    if (OUT/'full-playthrough.json').exists():
        report['after_full'] = summary('build/qa/gameplay-v93/reports/full-playthrough.json')
    reachable = set(design['focused_pool'])
    for k in catalog['selectable_leaders']:
        reachable.update([catalog['characters'][k]['starter'], catalog['characters'][k]['starter_supply']])
    while True:
        before = set(reachable)
        for r in catalog['recipes']:
            if r['base'] in reachable and set(r['materials']).issubset(reachable):
                reachable.add(r['target'])
        if before == reachable:
            break
    report['optimistic_closure'] = {
        'scope': 'Union ignoring money, time, space, weapon and signature eligibility. Not actual per-player access.',
        'items': len(reachable), 'recipes': sum(r['base'] in reachable and set(r['materials']).issubset(reachable) for r in catalog['recipes']),
    }
    report['controlled_balance'] = load('build/qa/gameplay-v93/reports/controlled-combos.json')
    (OUT/'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    with (OUT/'round-economy-quality.csv').open('w') as f:
        w = csv.writer(f)
        w.writerow(['round', 'base_grant', 'cumulative_base_budget', 'category', 'q1_pct', 'q2_pct', 'q3_pct', 'q4_pct'])
        for rn, grant in enumerate(design['income_by_round'], 1):
            for category, curve in design['shop']['category_tiers'].items():
                w.writerow([rn, grant, sum(design['income_by_round'][:rn]), category, *[round(v*100) for v in curve[str(rn)]]])
    with (OUT/'staged-supply.csv').open('w') as f:
        w = csv.writer(f);w.writerow(['id', 'name', 'entry_round', 'quality', 'price', 'tags'])
        for k, rn in sorted(design['offer_rounds'].items(), key=lambda row: (row[1], row[0])):
            d=items[k];w.writerow([k, d['name'], rn, d['rarity'], d['price'], '/'.join(d['tags'])])
    for key in ['before_focused', 'after_focused', 'after_full']:
        if key in report:
            s=report[key]
            print(key, json.dumps({k:s[k] for k in ['runs','battles','mean_battles','max_chain_depths','first_craft_rounds','runs_with_quality5_equipped','unique_acquisition_hashes']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
