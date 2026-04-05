#!/bin/bash
# memory-precompact.sh - PreCompact hook
# Fires before context compaction. Reminds Claude to save state NOW
# because context is about to be lost.
# Stdout from this hook IS visible to Claude.
#
# NOTE: Do NOT use `set -e` — jq failures must not kill the script.

# Source common utilities for backend-aware path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/memory-common.sh" 2>/dev/null || true

STATE_DIR=$(get_state_dir 2>/dev/null) || STATE_DIR="$HOME/.claude/.memory-hooks"
STATE_FILE="$STATE_DIR/activity.json"

EDITS=0
COMMITS=0
FILES_COUNT=0

if [ -f "$STATE_FILE" ] && jq empty "$STATE_FILE" 2>/dev/null; then
    EDITS=$(jq -r '.edits // 0' "$STATE_FILE" 2>/dev/null) || EDITS=0
    COMMITS=$(jq -r '.commits // 0' "$STATE_FILE" 2>/dev/null) || COMMITS=0
    FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE" 2>/dev/null) || FILES_COUNT=0
fi

# Detect backend for appropriate message
BACKEND=$(get_backend 2>/dev/null) || BACKEND="default"

if [ "$BACKEND" = "obsidian" ]; then
    echo "<memory-checkpoint reason=\"pre-compaction\" priority=\"critical\" backend=\"obsidian\">Context compaction is about to occur. BEFORE compaction completes, you MUST save ALL current state to your Obsidian vault: update the active session note in Sessions/ with what you are working on, Progress/ with current progress, and any unsaved decisions to Decisions/. Also update the hot cache at .claude-state/{project}/recent.md. You have $EDITS unsaved edits across $FILES_COUNT files and $COMMITS commits since last save.</memory-checkpoint>"
else
    echo "<memory-checkpoint reason=\"pre-compaction\" priority=\"critical\">Context compaction is about to occur. BEFORE compaction completes, you MUST save current state to memory files: update context/current-task.md with what you are working on, progress/active.md with current progress, and any unsaved decisions to decisions/. You have $EDITS unsaved edits across $FILES_COUNT files and $COMMITS commits since last save.</memory-checkpoint>"
fi

# Reset state after compaction nudge
if [ -f "$STATE_FILE" ]; then
    NOW=$(date +%s)
    jq --arg now "$NOW" '
        .edits = 0 |
        .commits = 0 |
        .files_changed = [] |
        .last_commit = "" |
        .last_nudge = ($now | tonumber)
    ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

exit 0
