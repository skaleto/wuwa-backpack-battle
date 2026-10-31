#!/bin/bash
TASK_GAME_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec open "$TASK_GAME_ROOT/releases/V2/macOS/索拉里斯大乱斗.app" --args "$@"
