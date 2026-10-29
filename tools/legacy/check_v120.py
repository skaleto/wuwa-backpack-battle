#!/usr/bin/env python3
"""V120 independent stars, placement feedback and cached render geometry."""
import check_v119 as previous
runner=previous.runner
runner.TESTS.update({'test_star_placement_v120':90,'test_render_cache_v120':90,'test_battle_case_v120':60})
if __name__=='__main__':
 import sys
 sys.exit(runner.main(revision='v120'))
