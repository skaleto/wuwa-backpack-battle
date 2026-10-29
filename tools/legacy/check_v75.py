#!/usr/bin/env python3
"""Current V75 headless regressions. Never runs the foreground launcher or player Storage."""
from pathlib import Path
import argparse, json, os, re, subprocess, sys, time
ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
TESTS = {
 'test_content_v75':90, 'test_shop_v75':120, 'test_battle_v75':60,
 'test_battle_v75_rules':180, 'test_storage_v75':90,
 'test_practice_v75':120, 'test_playthrough_v75':300, 'test_balance_v75':180,
 'test_craft_v75':120, 'test_chains_v75':120,
 'test_bag_replacement':60, 'test_item_displacement_v65':60,
 'test_drag_purchase_v18':60, 'test_interaction_v53':90,
 'test_star_feedback_v75':60, 'test_star_events_v75':60, 'test_ui_v75_controller':90,
 'test_visual_skin':60, 'test_cloth_corners_v67':60,
 'test_ui_v75':120, 'test_ui_v75_layout':120,
}
ERROR = re.compile(r'SCRIPT ERROR|(?:^|\n)\s*ERROR:|(?:^|\n)\s*FAIL\b|[1-9]\d* failures')
def decode(value):
 return value.decode('utf-8','replace') if isinstance(value,bytes) else value or ''
def execute(command, timeout):
 start=time.monotonic()
 try:
  result=subprocess.run(command,capture_output=True,text=True,timeout=timeout)
  output=result.stdout+result.stderr
  return {'ok':result.returncode==0 and not ERROR.search(output),'returncode':result.returncode,'timeout':False,'seconds':round(time.monotonic()-start,3),'output':output}
 except subprocess.TimeoutExpired as error:
  output=decode(error.stdout)+decode(error.stderr)+f'\nTIMEOUT after {timeout}s\n'
  return {'ok':False,'returncode':None,'timeout':True,'seconds':round(time.monotonic()-start,3),'output':output}
 except OSError as error:
  return {'ok':False,'returncode':None,'timeout':False,'seconds':round(time.monotonic()-start,3),'output':str(error)+'\n'}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('tests',nargs='*');args=parser.parse_args()
 tests=args.tests or list(TESTS)
 unknown=set(tests)-set(TESTS)
 if unknown:parser.error('unknown suite: '+', '.join(sorted(unknown)))
 logs=ROOT/'build/qa/gameplay-v75/checks';logs.mkdir(parents=True,exist_ok=True)
 summary={}
 for test in tests:
  result=execute([GODOT,'--headless','--path',str(ROOT),'--script',f'tests/{test}.gd'],TESTS[test])
  (logs/f'{test}.log').write_text(result.pop('output'))
  summary[test]=result
  print(('PASS' if result['ok'] else 'FAIL')+f" {test} ({result['seconds']}s)",flush=True)
 (logs/('suite-summary.json' if not args.tests else 'partial-summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
 passed=sum(v['ok'] for v in summary.values());print(f'{passed}/{len(tests)} passed')
 return int(passed!=len(tests))
if __name__=='__main__':sys.exit(main())
