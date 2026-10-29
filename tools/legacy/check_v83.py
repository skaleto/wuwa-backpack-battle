#!/usr/bin/env python3
"""Real event consumers + complete V81 regressions; headless, isolated QA saves only."""
from pathlib import Path
import argparse
import json
import sys
from check_v82 import TESTS as PREVIOUS_TESTS
from check_v75 import GODOT, execute
ROOT = Path(__file__).resolve().parents[2]
TESTS = {k:v for k,v in PREVIOUS_TESTS.items() if k not in ['test_operations_v78','test_process_equivalence_v78']}
TESTS.update({'test_operations_v83':120,'test_process_v83':240,'test_economy_v83':120,'test_early_balance_v83':120,'test_card_effects_v87':120})
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('tests',nargs='*')
    args=parser.parse_args()
    selected=args.tests or list(TESTS)
    unknown=set(selected)-TESTS.keys()
    if unknown:parser.error('unknown suite: '+', '.join(sorted(unknown)))
    logs=ROOT/'build/qa/balance-v83/checks'
    logs.mkdir(parents=True,exist_ok=True)
    summary={}
    for name in selected:
        result=execute([GODOT,'--headless','--path',str(ROOT),'--script',f'tests/{name}.gd'],TESTS[name])
        (logs/f'{name}.log').write_text(result.pop('output'))
        summary[name]=result
        print(('PASS' if result['ok'] else 'FAIL')+f" {name} ({result['seconds']}s)",flush=True)
    (logs/('partial-summary.json' if args.tests else 'suite-summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
    passed=sum(r['ok'] for r in summary.values())
    print(f'{passed}/{len(selected)} passed')
    return int(passed!=len(selected))
if __name__=='__main__':sys.exit(main())
