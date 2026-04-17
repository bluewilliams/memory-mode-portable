#!/bin/bash
# memory-tracker.sh - PostToolUse hook
# Silently tracks file edits and git commits to a state file.
# This hook's stdout is NOT visible to Claude — it just builds up state
# that memory-nudge.sh reads on the next user prompt.
#
# NOTE: Do NOT use `set -e` — jq failures on malformed input must not
# kill the script. Claude Code reports any non-zero exit as "hook error."

# Source common utilities for backend-aware path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/memory-common.sh" 2>/dev/null || true

STATE_DIR=$(get_state_dir 2>/dev/null) || STATE_DIR="$HOME/.claude/.memory-hooks"
STATE_FILE="$STATE_DIR/activity.json"
INIT_JSON='{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0,"cycles":0}'

mkdir -p "$STATE_DIR" 2>/dev/null || true

# Read stdin (Claude Code pipes hook context as JSON)
INPUT=$(cat 2>/dev/null) || true

# Bail silently if input is empty or not valid JSON
if [ -z "$INPUT" ] || ! echo "$INPUT" | jq empty 2>/dev/null; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || true

# Initialize state file if missing or corrupted
if [ ! -f "$STATE_FILE" ] || ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo "$INIT_JSON" > "$STATE_FILE"
fi

case "$TOOL_NAME" in
    Edit|Write|MultiEdit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
        if [ -n "$FILE_PATH" ]; then
            jq --arg fp "$FILE_PATH" '
                .edits += 1 |
                .files_changed = ((.files_changed + [$fp]) | unique)
            ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        ;;
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
        if [ -n "$COMMAND" ] && echo "$COMMAND" | grep -q "git commit" 2>/dev/null; then
            COMMIT_MSG=$(echo "$COMMAND" | head -1 | cut -c1-80)
            jq --arg cm "$COMMIT_MSG" '
                .commits += 1 |
                .last_commit = $cm
            ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        ;;
esac

exit 0
