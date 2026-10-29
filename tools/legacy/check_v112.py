#!/usr/bin/env python3
"""V112 interaction, presentation and public stamina regression."""
import check_v111 as previous
runner=previous.runner
runner.TESTS.update({"test_feedback_v112":90,"test_stamina_v112":60})
if __name__=="__main__":
 import sys
 sys.exit(runner.main(revision="v112"))
