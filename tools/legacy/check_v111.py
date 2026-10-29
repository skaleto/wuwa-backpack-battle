#!/usr/bin/env python3
"""Capacity-only expansion plus all current regressions, isolated QA storage."""
import check_v110 as previous
runner = previous.runner
runner.TESTS["test_capacity_v111"] = 90
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v111"))
