#!/bin/bash
set -euo pipefail
TASK_GAME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_GODOT_BIN="${TASK_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
TASK_CHECK_DIR="$TASK_GAME_ROOT/build/qa/v60/release-checks"
mkdir -p "$TASK_CHECK_DIR"
for TASK_TEST in test_battle_v60 test_content_v60 test_runs_v60 test_playthrough_v60 test_drag_purchase_v18 test_visual_skin; do
  "$TASK_GODOT_BIN" --headless --path "$TASK_GAME_ROOT" --script "tests/$TASK_TEST.gd" > "$TASK_CHECK_DIR/$TASK_TEST.log" 2>&1
  cat "$TASK_CHECK_DIR/$TASK_TEST.log"
done
"$TASK_GODOT_BIN" --headless --path "$TASK_GAME_ROOT" --quit-after 5 -- --profile=release-smoke > "$TASK_CHECK_DIR/startup.log" 2>&1
cat "$TASK_CHECK_DIR/startup.log"
if rg -n 'SCRIPT ERROR|ERROR:|FAIL ' "$TASK_CHECK_DIR"; then
  exit 1
fi
