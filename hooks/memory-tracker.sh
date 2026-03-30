#!/bin/bash
# memory-tracker.sh - PostToolUse hook
# Silently tracks file edits and git commits to a state file.
# This hook's stdout is NOT visible to Claude — it just builds up state
# that memory-nudge.sh reads on the next user prompt.

set -e

STATE_DIR="$HOME/.claude/.memory-hooks"
mkdir -p "$STATE_DIR"

STATE_FILE="$STATE_DIR/activity.json"
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
    echo '{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0}' > "$STATE_FILE"
fi

case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        if [ -n "$FILE_PATH" ]; then
            # Increment edit count and track file
            jq --arg fp "$FILE_PATH" '
                .edits += 1 |
                .files_changed = ((.files_changed + [$fp]) | unique)
            ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        ;;
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        if echo "$COMMAND" | grep -q "git commit"; then
            # Track commit
            COMMIT_MSG=$(echo "$COMMAND" | head -1 | cut -c1-80)
            jq --arg cm "$COMMIT_MSG" '
                .commits += 1 |
                .last_commit = $cm
            ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        ;;
esac

exit 0
