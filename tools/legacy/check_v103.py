#!/usr/bin/env python3
"""Full V103 regression; isolated saves, no foreground window or audio."""
import check_v102 as previous
runner = previous.runner
runner.TESTS.update({
    "test_unlimited_stash_v103": 60,
    "test_stash_pages_v103": 90,
    "test_bag_material_v103": 60,
    "test_bag_form_v103": 60,
})
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v103"))
