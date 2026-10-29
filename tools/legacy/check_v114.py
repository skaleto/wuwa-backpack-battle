#!/usr/bin/env python3
"""Free node recruitment, ten crew bonds, migration, and current regressions."""
import check_v113 as previous
runner = previous.runner
runner.TESTS.update({'test_recruitment_v114':60,'test_bonds_v114':90,'test_migration_recruitment_v114':90,'test_recruitment_ui_v114':90})
if __name__ == '__main__':
 import sys
 sys.exit(runner.main(revision='v114'))
