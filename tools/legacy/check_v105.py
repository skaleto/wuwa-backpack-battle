#!/usr/bin/env python3
"""Current visual and interaction checks with independent QA saves."""
import check_v104 as previous

runner = previous.runner
runner.TESTS.pop("test_bag_form_v103", None)
runner.TESTS["test_bag_layers_v105"] = 90
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v105"))
