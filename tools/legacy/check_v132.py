#!/usr/bin/env python3
"""V132 per-pocket rounded seam continuity; no gameplay rule changes."""
import sys
from check_v131 import runner
runner.TESTS.update({'test_joined_pockets_v132': 90})
if __name__ == '__main__':
    sys.exit(runner.main(revision='v132'))
