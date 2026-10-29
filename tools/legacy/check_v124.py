#!/usr/bin/env python3
"""Branching recipes, twelve combination cores, exact migration and atlas."""
import check_v123 as previous
runner = previous.runner
runner.TESTS.update({
    'test_craft_v124': 90,
    'test_strategy_v124': 90,
    'test_core_combat_v124': 90,
    'test_migration_v124': 90,
    'test_recipe_atlas_v124': 90,
    'test_recipe_atlas_boundary_v124': 90,
    'test_chains_v124': 60,
})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v124'))
