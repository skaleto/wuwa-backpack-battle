#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
check_log_dir="${CHECK_LOG_DIR:-build/qa/ui-v56/checks}"
mkdir -p "$check_log_dir"
"$godot_bin" --headless --path . --editor --import > "$check_log_dir/import.log" 2>&1
for name in test_demo_interaction test_drag_purchase_v18 test_pockets_v26 test_bag_replacement test_crafting_v15 test_crafting_migration test_v4_migration test_item_polish_v43 test_cooldown_v18 test_motion_v24 test_native_rigs_v24 test_portrait_lighting_v20 test_frequency_grid test_playable_v50 test_playable_ui_v50 test_normal_runs_v50 test_review_fixes_v50 test_direct_play_v53 test_migration_v53 test_interaction_v53 test_audio_v53 test_centered_turn_v54 test_paper_v54 test_polish_v55 test_feedback_v56 test_supply_v56 test_practice_v56; do
  if ! "$godot_bin" --headless --path . --script "tests/$name.gd" > "$check_log_dir/$name.log" 2>&1; then
    cat "$check_log_dir/$name.log"
    exit 1
  fi
  if rg -q 'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL' "$check_log_dir/$name.log"; then
    cat "$check_log_dir/$name.log"
    exit 1
  fi
  tail -1 "$check_log_dir/$name.log"
done
