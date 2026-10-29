#!/usr/bin/env python3
"""Persistent craft links and storage fallback + complete V78 regressions; headless, isolated QA saves only."""
from pathlib import Path
import argparse
import json
import sys
from check_v78 import TESTS as PREVIOUS_TESTS
from check_v75 import GODOT, execute
ROOT = Path(__file__).resolve().parents[2]
TESTS = {**PREVIOUS_TESTS, 'test_craft_storage_v79':120, 'test_links_v79':120}
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('tests',nargs='*')
    args=parser.parse_args()
    selected=args.tests or list(TESTS)
    unknown=set(selected)-TESTS.keys()
    if unknown:parser.error('unknown suite: '+', '.join(sorted(unknown)))
    logs=ROOT/'build/qa/ui-v79/checks'
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
