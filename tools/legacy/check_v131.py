#!/usr/bin/env python3
"""V131 reference cloth artwork and approved bag audio gain; gameplay unchanged."""
import sys
from check_v130 import runner
runner.TESTS.update({'test_bag_feedback_v131': 90})
if __name__ == '__main__':
    sys.exit(runner.main(revision='v131'))
