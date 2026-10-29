#!/usr/bin/env python3
"""Approved pastel bags and existing behavior regressions, isolated QA only."""
import check_v109 as previous
runner = previous.runner
runner.TESTS["test_bag_style_v110"] = 90
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v110"))
