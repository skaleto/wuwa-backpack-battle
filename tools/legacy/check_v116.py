#!/usr/bin/env python3
"""V116 geometry, contact bonuses, migration and all current regressions."""
import check_v115 as previous
runner = previous.runner
runner.TESTS.update({"test_pockets_v116": 60, "test_icon_fit_v116": 180, "test_migration_v116": 120, "test_feedback_ui_v116": 90, "test_vfx_v116": 120})
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v116"))
