#!/usr/bin/env python3
"""Bag style trials and existing independent-save regressions."""
import check_v107 as previous
runner = previous.runner
runner.TESTS["test_bag_styles_v109"] = 90
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v109"))
