#!/usr/bin/env python3
"""V101 regressions. All simulation/storage checks run headless with QA paths."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
import sys

from check_v93 import TESTS as PREVIOUS_TESTS
from check_v75 import GODOT, execute

ROOT = Path(__file__).resolve().parents[2]
TESTS = dict(PREVIOUS_TESTS)
TESTS.update({"test_high_tier_stars_v101": 90, "test_migration_v101": 90, "test_battle_review_v101": 60})
TESTS["test_fusion_audio_v101"]=60


def main(revision="v101"):
    parser = argparse.ArgumentParser()
    parser.add_argument("tests", nargs="*")
    parser.add_argument("--jobs", type=int, default=1, choices=[1, 2])
    args = parser.parse_args()
    selected = args.tests or list(TESTS)
    if set(selected) - TESTS.keys():
        parser.error("unknown suite: " + ", ".join(sorted(set(selected) - TESTS.keys())))
    logs = ROOT / f"build/qa/feedback-{revision}/checks"
    logs.mkdir(parents=True, exist_ok=True)

    def run_one(name):
        result = execute([GODOT, "--headless", "--path", str(ROOT), "--script", f"tests/{name}.gd"], TESTS[name])
        (logs / f"{name}.log").write_text(result.pop("output"))
        print(("PASS" if result["ok"] else "FAIL") + f" {name} ({result['seconds']}s)", flush=True)
        return name, result

    with ThreadPoolExecutor(max_workers=args.jobs) as workers:
        summary = dict(workers.map(run_one, selected))
    (logs / ("partial-summary.json" if args.tests else "suite-summary.json")).write_text(json.dumps(summary, indent=2) + "\n")
    passed = sum(r["ok"] for r in summary.values())
    print(f"{passed}/{len(selected)} passed")
    return int(passed != len(selected))


if __name__ == "__main__":
    sys.exit(main())
