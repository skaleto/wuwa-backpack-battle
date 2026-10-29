#!/usr/bin/env python3
"""V76 interaction regressions plus the full V75 suite; no player saves or UI focus."""
from pathlib import Path
import argparse
import json
import sys
from check_v75 import GODOT, TESTS as PREVIOUS_TESTS, execute

ROOT = Path(__file__).resolve().parents[2]
TESTS = {**PREVIOUS_TESTS, 'test_guidance_v76': 120, 'test_bag_stash_v76': 120, 'test_drop_feedback_v65': 90}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('tests', nargs='*')
    args = parser.parse_args()
    selected = args.tests or list(TESTS)
    unknown = set(selected) - TESTS.keys()
    if unknown:
        parser.error('unknown suite: ' + ', '.join(sorted(unknown)))
    logs = ROOT / 'build/qa/ui-v76/checks'
    logs.mkdir(parents=True, exist_ok=True)
    summary = {}
    for name in selected:
        result = execute([GODOT, '--headless', '--path', str(ROOT), '--script', f'tests/{name}.gd'], TESTS[name])
        (logs / f'{name}.log').write_text(result.pop('output'))
        summary[name] = result
        print(('PASS' if result['ok'] else 'FAIL') + f" {name} ({result['seconds']}s)", flush=True)
    (logs / ('partial-summary.json' if args.tests else 'suite-summary.json')).write_text(json.dumps(summary, indent=2) + '\n')
    passed = sum(result['ok'] for result in summary.values())
    print(f'{passed}/{len(selected)} passed')
    return int(passed != len(selected))

if __name__ == '__main__':
    sys.exit(main())
