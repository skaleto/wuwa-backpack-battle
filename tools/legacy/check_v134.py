#!/usr/bin/env python3
"""Async protocol, durable transitions, UI isolation and existing regressions."""
import sys
from check_v133 import runner
runner.TESTS.update({
    'test_async_pvp_v134': 60,
    'test_async_run_v134': 90,
    'test_async_network_v134': 60,
    'test_async_ui_v134': 90,
    'test_async_storage_v134': 90,
    'test_async_upload_retry_v134': 60,
})
if __name__ == '__main__':
    sys.exit(runner.main(revision='v134'))
