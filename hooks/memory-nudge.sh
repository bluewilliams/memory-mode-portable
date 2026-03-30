#!/bin/bash
# memory-nudge.sh - UserPromptSubmit hook
# Checks accumulated activity and injects a memory checkpoint nudge
# into Claude's context when significant work has happened.
# Stdout from this hook IS visible to Claude.

STATE_DIR="$HOME/.claude/.memory-hooks"
STATE_FILE="$STATE_DIR/activity.json"

# No state file = nothing to nudge about
if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

EDITS=$(jq -r '.edits // 0' "$STATE_FILE")
COMMITS=$(jq -r '.commits // 0' "$STATE_FILE")
LAST_NUDGE=$(jq -r '.last_nudge // 0' "$STATE_FILE")
NOW=$(date +%s)

# Minimum 5 minutes between nudges to avoid being annoying
ELAPSED=$((NOW - LAST_NUDGE))
if [ "$ELAPSED" -lt 300 ]; then
    exit 0
fi

# Thresholds for nudging
NUDGE=""
if [ "$COMMITS" -gt 0 ]; then
    FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE")
    NUDGE="<memory-checkpoint reason=\"post-commit\">You have made $COMMITS commit(s) and edited $FILES_COUNT file(s) since your last memory save. If memory mode is active, update context/current-task.md and progress/active.md to reflect current state before continuing.</memory-checkpoint>"
elif [ "$EDITS" -ge 10 ]; then
    FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE")
    NUDGE="<memory-checkpoint reason=\"edit-threshold\">You have edited $FILES_COUNT file(s) ($EDITS total edits) since your last memory save. If memory mode is active, consider saving a checkpoint to context/current-task.md.</memory-checkpoint>"
fi

if [ -n "$NUDGE" ]; then
    echo "$NUDGE"
    # Reset counters and record nudge time
    jq --arg now "$NOW" '
        .edits = 0 |
        .commits = 0 |
        .files_changed = [] |
        .last_commit = "" |
        .last_nudge = ($now | tonumber)
    ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

exit 0
