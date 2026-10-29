#!/usr/bin/env python3
"""Free-combination recruitment plus all published behavior regressions."""
import check_v114 as previous
runner=previous.runner
runner.TESTS.update({'test_recruitment_v115':60,'test_crew_combat_v115':90,'test_recruitment_ui_v115':90,'test_playthrough_v115':600})
if __name__=='__main__':
 import sys
 sys.exit(runner.main(revision='v115'))
