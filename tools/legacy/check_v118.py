#!/usr/bin/env python3
"""V118 illustrated buttons and existing gameplay regressions."""
import check_v117 as previous
runner = previous.runner
runner.TESTS.update({"test_buttons_v118": 90})
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v118"))
