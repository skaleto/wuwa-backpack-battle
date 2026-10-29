#!/usr/bin/env python3
"""V130 fine cloth seams and distinct grab/landing audio; gameplay unchanged."""
import check_v129 as previous
runner = previous.runner
runner.TESTS.update({'test_bag_audio_v130': 90, 'test_fine_seams_v130': 90})
if __name__ == '__main__':
    import sys
    sys.exit(runner.main(revision='v130'))
