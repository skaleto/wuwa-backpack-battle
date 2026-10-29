#!/usr/bin/env python3
"""Container artwork checks with independent QA saves."""
import check_v105 as previous

if __name__ == "__main__":
    import sys
    sys.exit(previous.runner.main(revision="v106"))
