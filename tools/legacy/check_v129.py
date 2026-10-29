#!/usr/bin/env python3
"""V129 pocket catalog, transactions, frozen supply and exact V128 migration."""
import check_v128 as previous
runner = previous.runner
runner.TESTS.update({
    'test_pockets_catalog_v129': 90,
    'test_pockets_transactions_v129': 90,
    'test_pockets_supply_v129': 180,
    'test_pockets_migration_v129': 90,
    'test_pocket_art_v129': 90,
})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v129'))
