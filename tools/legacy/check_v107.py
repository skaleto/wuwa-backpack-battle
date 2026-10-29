#!/usr/bin/env python3
"""Container contact checks and existing behavior regressions, isolated QA only."""
import check_v105 as previous
runner = previous.runner
runner.TESTS["test_bag_contacts_v107"] = 60
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v107"))
