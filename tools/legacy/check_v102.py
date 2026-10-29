#!/usr/bin/env python3
"""Current complete headless regressions; never opens the player's save/window."""
import check_v101 as runner
runner.TESTS.update({"test_presentation_v102": 60, "test_fusion_v102": 60})
# Keep earlier validation evidence intact, even when reusing its runner.
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v102"))
