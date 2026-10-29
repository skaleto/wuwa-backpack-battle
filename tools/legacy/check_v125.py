#!/usr/bin/env python3
"""Item ecosystem, functional supply budgets and complete existing regression."""
import check_v124 as previous
runner = previous.runner
runner.TESTS.update({'test_ecosystem_v125':90,'test_ecosystem_edges_v125':90,'test_ecosystem_content_v125':90})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v125'))
