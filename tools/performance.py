#!/usr/bin/env python3
"""Replay a saved battle in a hidden native viewport; independent QA Storage."""
import argparse,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--case',type=Path,default=ROOT/'tests/fixtures/data/feedback-v120/input/hsin-round10.json')
p.add_argument('--tag',default='final')
p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
p.add_argument('--full',action='store_true',help='Play all recorded battle events through to the final frame')
p.add_argument('--measure-only',action='store_true',help='Save metrics without enforcing local rendering budget')
a=p.parse_args()
if not re.fullmatch(r'[a-zA-Z0-9_-]{1,64}',a.tag):p.error('tag must be 1–64 letters, digits, _ or -')
case=a.case.resolve()
try:
 d=json.loads(case.read_text())
 if not d.get('combat',{}).get('frames') or not d.get('opponent'):raise ValueError('missing combat.frames or opponent')
except (OSError,ValueError) as e:p.error(str(e))
cmd=[a.godot,'--path',str(ROOT),'--script','tests/visual/profile_battle_v120.gd','--','--case='+str(case),'--tag='+a.tag]
if not a.measure_only:cmd.append('--verify')
if a.full:cmd.append('--full')
(ROOT/'build/qa/feedback-v120').mkdir(parents=True,exist_ok=True)
result=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
report=ROOT/f'build/qa/feedback-v120/performance-{a.tag}.json'
errors=any(key in result.stdout for key in ['SCRIPT ERROR:','Parse Error:','FAIL '])
(ROOT/f'build/qa/feedback-v120/performance-{a.tag}.log').write_text(result.stdout)
if report.exists() and result.returncode==0 and not errors:
 r=json.loads(report.read_text())
 print(f"{'PASS' if r['passed'] else 'MEASURED'} {r['leader']} round {r['round']:.0f}, {r['item_counts']}: draw {r['draw_ms']['mean']:.2f} ms, p95 {r['draw_ms']['p95']:.2f} ms; frame wait p95 {r['wall_frame_ms']['p95']:.2f} ms; {r['draw_calls']['mean']:.0f} calls")
 print(report)
else:print(result.stdout)
sys.exit(1 if errors else result.returncode)
