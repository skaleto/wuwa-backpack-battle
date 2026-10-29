#!/usr/bin/env python3
"""Current release checks. Never opens a window or touches the real player store."""
from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[2]
logs=root/'build/qa/ui-v70/checks';logs.mkdir(parents=True,exist_ok=True)
tests=['test_content_v60','test_battle_v60','test_runs_v60','test_playthrough_v60','test_opening_v70','test_storage_v70','test_visual_skin','test_item_displacement_v65','test_drag_purchase_v18','test_star_feedback_v65','test_cloth_corners_v67','test_inline_craft_v69','test_chains_v70','test_ui_v70']
for candidate in ['test_item_atlas_v70']:
 if (root/'tests'/f'{candidate}.gd').exists():tests.append(candidate)
failures=[]
for test in tests:
 try:
  result=subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(root),'--script',f'tests/{test}.gd'],capture_output=True,text=True,timeout=90)
  output=result.stdout+result.stderr
  failed=result.returncode!=0 or any(v in output for v in ['SCRIPT ERROR','ERROR:','FAIL '])
 except subprocess.TimeoutExpired as error:
  output='TIMEOUT: '+str(error);failed=True
 (logs/f'{test}.log').write_text(output)
 print(('FAIL' if failed else 'PASS')+' '+test,flush=True)
 if failed:failures.append(test)
print(f'{len(tests)-len(failures)}/{len(tests)} passed')
sys.exit(bool(failures))
