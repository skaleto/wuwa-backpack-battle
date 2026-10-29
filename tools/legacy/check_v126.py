#!/usr/bin/env python3
"""Opening simplification and combat presentation; preserves all gameplay checks."""
import check_v125 as previous
runner = previous.runner
runner.TESTS.update({'test_spectacle_v126':90})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v126'))
