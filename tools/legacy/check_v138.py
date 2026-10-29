#!/usr/bin/env python3
import sys
from check_v137 import runner
runner.TESTS.update({'test_release_v138':60,'test_release_storage_v138':60,'test_match_sampling_v138':60})
if __name__ == '__main__':
    from release_manifest import ROOT,compute
    import json
    if json.loads((ROOT/'data/release-hashes.json').read_text())!=compute():raise SystemExit('Stale release hashes')
    sys.exit(runner.main(revision='v138'))
