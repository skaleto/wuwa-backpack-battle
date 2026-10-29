#!/usr/bin/env python3
"""Lobby routes and save isolation; inherits the gameplay regression suites."""
import sys
from check_v134 import runner
runner.TESTS.update({'test_lobby_v135': 90})
if __name__ == '__main__':
    sys.exit(runner.main(revision='v135'))
