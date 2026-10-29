#!/usr/bin/env python3
"""V119 opening presentation, complete-width portraits and UI regressions."""
import check_v118 as previous
runner = previous.runner
runner.TESTS.update({"test_portrait_source_v119": 60, "test_opening_v119": 120})
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v119"))
