#!/usr/bin/env python3
"""V104 presentation regression using the existing isolated-save suites."""
import check_v103 as previous

runner = previous.runner
if __name__ == "__main__":
    import sys
    sys.exit(runner.main(revision="v104"))
