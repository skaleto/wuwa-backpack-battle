#!/bin/bash
TASK_GAME_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$TASK_GAME_ROOT" "$@"
