#!/usr/bin/env python3
"""Family content, current recipes, useful combat and versioned procurement."""
import check_v126 as previous
runner=previous.runner
runner.TESTS.update({'test_families_catalog_v127':90,'test_families_effects_v127':90,'test_families_supply_v127':90,'test_families_chains_v127':180,'test_families_practice_v127':180})
if __name__=='__main__':
    import sys
    sys.exit(runner.main(revision='v127'))
