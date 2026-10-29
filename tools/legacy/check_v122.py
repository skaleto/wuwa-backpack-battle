#!/usr/bin/env python3
"""Persistent replay, progressive shop supply and bounded quality particles."""
import check_v121 as previous
runner=previous.runner
runner.TESTS.update({'test_history_v122':60,'test_history_ui_v122':90,'test_history_application_v122':90,'test_glints_v122':60,'test_supply_v122':120,'test_supply_storage_v122':60})
if __name__=='__main__':
 import sys
 sys.exit(runner.main(revision='v122'))
