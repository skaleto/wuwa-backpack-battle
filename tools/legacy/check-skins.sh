#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
skin_log_dir="build/qa/demo-v50/skins/checks"
mkdir -p "$skin_log_dir"
for test in test_visual_skin test_skin_integration test_skin_cache validate_skin_assets; do
  "$godot_bin" --headless --path . --script "tests/$test.gd" > "$skin_log_dir/$test.log" 2>&1
  if rg -q 'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL' "$skin_log_dir/$test.log"; then
    cat "$skin_log_dir/$test.log"
    exit 1
  fi
  tail -1 "$skin_log_dir/$test.log"
done
for skin in original chibi; do
  for test in test_demo_interaction test_drag_purchase_v18 test_pockets_v26 test_bag_replacement test_playable_ui_v50 test_review_fixes_v50; do
    "$godot_bin" --headless --path . --script "tests/$test.gd" -- "--visual-skin=$skin" > "$skin_log_dir/$skin-$test.log" 2>&1
    if rg -q 'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL' "$skin_log_dir/$skin-$test.log"; then
      cat "$skin_log_dir/$skin-$test.log"
      exit 1
    fi
    tail -1 "$skin_log_dir/$skin-$test.log"
  done
done
