#!/usr/bin/env python3
"""Real event consumers + complete V81 regressions; headless, isolated QA saves only."""
from pathlib import Path
import argparse
import json
import sys
from check_v84 import TESTS as PREVIOUS_TESTS
from check_v75 import GODOT, execute
ROOT = Path(__file__).resolve().parents[2]
TESTS = {k:v for k,v in PREVIOUS_TESTS.items() if k!="test_transfer_reflow_v65"}
TESTS.update({'test_taper_v85':60,'test_weapons_materials_v86':120,'test_replacement_v86':120,'test_migration_v86':120})
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('tests',nargs='*')
    args=parser.parse_args()
    selected=args.tests or list(TESTS)
    unknown=set(selected)-TESTS.keys()
    if unknown:parser.error('unknown suite: '+', '.join(sorted(unknown)))
    logs=ROOT/'build/qa/gameplay-v86/checks'
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
