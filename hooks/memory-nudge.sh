#!/bin/bash
# memory-nudge.sh - UserPromptSubmit hook
# Checks accumulated activity and injects a memory checkpoint nudge
# into Claude's context when significant work has happened.
# Stdout from this hook IS visible to Claude.
#
# Triggers (in priority order):
#   1. Post-commit: any commit = nudge immediately (bypasses rate limit)
#   2. Cycle-based: every 3 UserPromptSubmit cycles with any activity = nudge
#   3. Time-based: 15+ minutes since last nudge with any activity = nudge
#   4. Pure-conversation: 5+ cycles with zero activity = self-assess nudge
#      (catches long discussions that produced no file edits but may contain
#      decisions, findings, or new people worth capturing)
#
# NOTE: Do NOT use `set -e` — jq failures must not kill the script.

# Source common utilities for backend-aware path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/memory-common.sh" 2>/dev/null || true

STATE_DIR=$(get_state_dir 2>/dev/null) || STATE_DIR="$HOME/.claude/.memory-hooks"
STATE_FILE="$STATE_DIR/activity.json"

# Tunable thresholds
CYCLES_THRESHOLD=3              # nudge every N cycles if activity present
TIME_THRESHOLD_SEC=900          # 15 min - time-based nudge
MIN_NUDGE_GAP_SEC=300           # 5 min minimum between non-commit nudges
PURE_CYCLES_THRESHOLD=5         # nudge every N cycles when no file activity

# No state file = nothing to nudge about
if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# If state file is corrupted, reset it silently
if ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo '{"edits":0,"commits":0,"files_changed":[],"last_commit":"","last_nudge":0,"cycles":0}' > "$STATE_FILE"
    exit 0
fi

EDITS=$(jq -r '.edits // 0' "$STATE_FILE" 2>/dev/null) || EDITS=0
COMMITS=$(jq -r '.commits // 0' "$STATE_FILE" 2>/dev/null) || COMMITS=0
LAST_NUDGE=$(jq -r '.last_nudge // 0' "$STATE_FILE" 2>/dev/null) || LAST_NUDGE=0
CYCLES=$(jq -r '.cycles // 0' "$STATE_FILE" 2>/dev/null) || CYCLES=0
NOW=$(date +%s)
ELAPSED=$((NOW - LAST_NUDGE))

# Always increment cycle counter for this prompt (before any bail-outs)
NEW_CYCLES=$((CYCLES + 1))
jq --argjson c "$NEW_CYCLES" '.cycles = $c' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Detect backend for appropriate nudge message
BACKEND=$(get_backend 2>/dev/null) || BACKEND="default"

# Determine if we should nudge and why
NUDGE=""
REASON=""
ACTIVITY=$((EDITS + COMMITS))

# Priority 1: Commits always nudge (bypass rate limit)
if [ "$COMMITS" -gt 0 ]; then
    REASON="post-commit"
    FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE" 2>/dev/null) || FILES_COUNT=0
    if [ "$BACKEND" = "obsidian" ]; then
        NUDGE="<memory-checkpoint reason=\"post-commit\" backend=\"obsidian\">You have made $COMMITS commit(s) and edited $FILES_COUNT file(s) since your last memory save. If memory mode is active, update the active session note in Sessions/ and the progress note in Progress/ in your Obsidian vault to reflect current state.</memory-checkpoint>"
    else
        NUDGE="<memory-checkpoint reason=\"post-commit\">You have made $COMMITS commit(s) and edited $FILES_COUNT file(s) since your last memory save. If memory mode is active, update context/current-task.md and progress/active.md to reflect current state before continuing.</memory-checkpoint>"
    fi
elif [ "$ELAPSED" -ge "$MIN_NUDGE_GAP_SEC" ] && [ "$ACTIVITY" -gt 0 ]; then
    # Priority 2: Cycle-based - every N cycles with activity
    if [ "$NEW_CYCLES" -ge "$CYCLES_THRESHOLD" ]; then
        REASON="cycle-checkpoint"
        FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE" 2>/dev/null) || FILES_COUNT=0
        if [ "$BACKEND" = "obsidian" ]; then
            NUDGE="<memory-checkpoint reason=\"cycle-checkpoint\" backend=\"obsidian\">$NEW_CYCLES conversation cycles with $EDITS edit(s) across $FILES_COUNT file(s) since your last memory save. If anything worth capturing happened - decisions, analysis findings, progress, new context - update the active session note in Sessions/ and the hot cache in .claude-state/{project}/recent.md. If nothing is worth saving, acknowledge silently and continue.</memory-checkpoint>"
        else
            NUDGE="<memory-checkpoint reason=\"cycle-checkpoint\">$NEW_CYCLES conversation cycles with $EDITS edit(s) across $FILES_COUNT file(s) since your last memory save. If anything worth capturing happened, update context/current-task.md.</memory-checkpoint>"
        fi
    # Priority 3: Time-based - 15+ minutes since last nudge with activity
    elif [ "$ELAPSED" -ge "$TIME_THRESHOLD_SEC" ]; then
        REASON="time-checkpoint"
        FILES_COUNT=$(jq -r '.files_changed | length' "$STATE_FILE" 2>/dev/null) || FILES_COUNT=0
        MINUTES=$((ELAPSED / 60))
        if [ "$BACKEND" = "obsidian" ]; then
            NUDGE="<memory-checkpoint reason=\"time-checkpoint\" backend=\"obsidian\">$MINUTES minutes since last save, with $EDITS edit(s) across $FILES_COUNT file(s). If anything worth capturing happened - decisions, analysis findings, progress, new context - update the active session note in Sessions/ and the hot cache in .claude-state/{project}/recent.md.</memory-checkpoint>"
        else
            NUDGE="<memory-checkpoint reason=\"time-checkpoint\">$MINUTES minutes since last save with $EDITS edit(s) across $FILES_COUNT file(s). Consider a checkpoint to context/current-task.md.</memory-checkpoint>"
        fi
    fi
# Priority 4: Pure-conversation - cycles accumulated with zero file activity
elif [ "$ELAPSED" -ge "$MIN_NUDGE_GAP_SEC" ] && [ "$ACTIVITY" -eq 0 ] && [ "$NEW_CYCLES" -ge "$PURE_CYCLES_THRESHOLD" ]; then
    REASON="pure-conversation"
    if [ "$BACKEND" = "obsidian" ]; then
        NUDGE="<memory-checkpoint reason=\"pure-conversation\" backend=\"obsidian\">$NEW_CYCLES conversation cycles with no file activity. Self-assess: did any decisions, analysis findings, context shifts, or preferences emerge in this discussion? If yes, update the active session note in Sessions/ and the hot cache in .claude-state/{project}/recent.md. Also scan for new people mentioned - if anyone lacks a note in People/, use AskUserQuestion to learn about them. If nothing is worth saving, acknowledge silently and continue.</memory-checkpoint>"
    else
        NUDGE="<memory-checkpoint reason=\"pure-conversation\">$NEW_CYCLES conversation cycles with no file activity. If decisions or findings emerged, update context/current-task.md.</memory-checkpoint>"
    fi
fi

if [ -n "$NUDGE" ]; then
    echo "$NUDGE"
    # Reset counters and record nudge time
    jq --arg now "$NOW" '
        .edits = 0 |
        .commits = 0 |
        .files_changed = [] |
        .last_commit = "" |
        .last_nudge = ($now | tonumber) |
        .cycles = 0
    ' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

exit 0
