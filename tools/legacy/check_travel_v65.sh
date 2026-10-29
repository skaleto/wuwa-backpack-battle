#!/bin/bash
set -euo pipefail
TASK_GAME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_GODOT_BIN="${TASK_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
TASK_CHECK_DIR="$TASK_GAME_ROOT/build/qa/ui-v65/checks"
mkdir -p "$TASK_CHECK_DIR"
for TASK_TEST in test_item_displacement_v65 test_drag_purchase_v18 test_drop_feedback_v65 test_transfer_reflow_v65 test_star_feedback_v65 test_travel_grid_v64 test_layout_v52 test_visual_skin test_click_details_v51 test_centered_turn_v54 test_interaction_v53 test_direct_play_v53; do
  "$TASK_GODOT_BIN" --headless --path "$TASK_GAME_ROOT" --script "tests/$TASK_TEST.gd" > "$TASK_CHECK_DIR/$TASK_TEST.log" 2>&1
  cat "$TASK_CHECK_DIR/$TASK_TEST.log"
  if rg -n 'SCRIPT ERROR|ERROR:|FAIL ' "$TASK_CHECK_DIR/$TASK_TEST.log"; then exit 1; fi
done
if [[ "${1:-}" == "--native" ]]; then
  for TASK_TEST in capture_travel_v65 test_drop_feedback_v65 test_transfer_reflow_v65 test_travel_flow_v65; do
    "$TASK_GODOT_BIN" --path "$TASK_GAME_ROOT" --script "tests/$TASK_TEST.gd" > "$TASK_CHECK_DIR/$TASK_TEST.native.log" 2>&1
    cat "$TASK_CHECK_DIR/$TASK_TEST.native.log"
    if rg -n 'SCRIPT ERROR|ERROR:|FAIL ' "$TASK_CHECK_DIR/$TASK_TEST.native.log"; then exit 1; fi
  done
fi
