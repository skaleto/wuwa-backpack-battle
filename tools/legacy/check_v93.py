#!/usr/bin/env python3
"""Progression, staged supply, battle readability and all current regressions; isolated QA only."""
from pathlib import Path
import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from check_v92 import TESTS as PREVIOUS_TESTS
from check_v75 import GODOT, execute
ROOT = Path(__file__).resolve().parents[2]
TESTS=dict(PREVIOUS_TESTS)
TESTS["test_playthrough_v75"]=600
TESTS.update({'test_progression_v93':90, 'test_supply_v93':90, 'test_migration_v93':90, 'test_battle_readability_v93':90, 'test_practice_performance_v93':120})
TESTS.update({'test_audio_v53':30, 'test_music_v94':60})
TESTS['test_weapon_audio_v95']=30
TESTS['test_feedback_v99']=60
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('tests',nargs='*')
    parser.add_argument('--jobs',type=int,default=1,choices=[1,2],help='Independent processes with isolated QA storage')
    args=parser.parse_args()
    selected=args.tests or list(TESTS)
    unknown=set(selected)-TESTS.keys()
    if unknown:parser.error('unknown suite: '+', '.join(sorted(unknown)))
    logs=ROOT/'build/qa/gameplay-v93/checks'
    logs.mkdir(parents=True,exist_ok=True)
    summary={}
    def run_one(name):
        result=execute([GODOT,'--headless','--path',str(ROOT),'--script',f'tests/{name}.gd'],TESTS[name])
        (logs/f'{name}.log').write_text(result.pop('output'))
        print(('PASS' if result['ok'] else 'FAIL')+f" {name} ({result['seconds']}s)",flush=True)
        return name,result
    with ThreadPoolExecutor(max_workers=args.jobs) as workers:
        summary.update(workers.map(run_one,selected))
    (logs/('partial-summary.json' if args.tests else 'suite-summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
    passed=sum(r['ok'] for r in summary.values())
    print(f'{passed}/{len(selected)} passed')
    return int(passed!=len(selected))
if __name__=='__main__':sys.exit(main())
