#!/bin/bash
# memory-precompact.sh - PreCompact hook
# Fires before context compaction. Reminds Claude to save state NOW
# because context is about to be lost.
# Stdout from this hook IS visible to Claude.

STATE_DIR="$HOME/.claude/.memory-hooks"
STATE_FILE="$STATE_DIR/activity.json"

EDITS=0
COMMITS=0
FILES_COUNT=0

if [ -f "$STATE_FILE" ]; then
    EDITS=$(jq -r '.edits // 0' "$STATE_FILE")
    COMMITS=$(jq -r '.commits // 0' "$STATE_FILE")
    FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE")
fi

echo "<memory-checkpoint reason=\"pre-compaction\" priority=\"critical\">Context compaction is about to occur. BEFORE compaction completes, you MUST save current state to memory files: update context/current-task.md with what you are working on, progress/active.md with current progress, and any unsaved decisions to decisions/. You have $EDITS unsaved edits across $FILES_COUNT files and $COMMITS commits since last save.</memory-checkpoint>"

# Reset state after compaction nudge
if [ -f "$STATE_FILE" ]; then
    NOW=$(date +%s)
    jq --arg now "$NOW" '
        .edits = 0 |
        .commits = 0 |
        .files_changed = [] |
        .last_commit = "" |
        .last_nudge = ($now | tonumber)
    ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

exit 0
