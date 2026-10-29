#!/usr/bin/env python3
"""V117 one-shot star feedback, surface light and full gameplay regressions."""
import check_v116 as previous
runner = previous.runner
runner.TESTS.update({"test_feedback_v117": 90})
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v117"))
