#!/usr/bin/env python3
"""Full archived battlefield playback and exact layout previews."""
import check_v122 as previous
runner = previous.runner
runner.TESTS.update({'test_history_playback_v123': 90, 'test_history_exit_v123': 90})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v123'))
