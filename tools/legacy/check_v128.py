#!/usr/bin/env python3
"""Original-item catalogue, actual combat, atomic recipes and frozen V127 supply."""
import check_v127 as previous
runner=previous.runner
runner.TESTS.update({'test_original_catalog_v128':90,'test_original_effects_v128':90,'test_original_supply_v128':120,'test_original_chains_v128':180,'test_original_migration_v128':90})
runner.TESTS.update({'test_original_assets_v128':90,'test_original_practice_v128':180})
if __name__=='__main__':
    import sys
    sys.exit(runner.main(revision='v128'))
