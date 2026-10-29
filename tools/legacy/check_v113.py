#!/usr/bin/env python3
"""Open equipment, compositional recruitment, and all current regressions."""
import check_v112 as previous
runner=previous.runner
runner.TESTS.update({'test_open_weapons_v113':120,'test_historical_qualification_v113':90,'test_crew_combat_v113':90})
if __name__=='__main__':
 import sys
 sys.exit(runner.main(revision='v113'))
