#!/usr/bin/env python3
"""V121 short independent feedback and full-content display cache."""
import check_v120 as previous
runner=previous.runner
runner.TESTS.update({'test_star_tempo_v121':60,'test_presentation_stamp_v121':60,'test_craft_display_v121':90})
if __name__=='__main__':
 import sys
 sys.exit(runner.main(revision='v121'))
