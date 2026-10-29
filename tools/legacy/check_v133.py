#!/usr/bin/env python3
"""V133 standalone pocket rendering; unchanged gameplay regressions."""
import sys
from check_v132 import runner
if __name__ == '__main__':
    sys.exit(runner.main(revision='v133'))
