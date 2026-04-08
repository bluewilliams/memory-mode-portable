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
    CLAUDE_ROOT=$(get_claude_root 2>/dev/null) || CLAUDE_ROOT=""
    cat << PRECOMPACT_EOF
<memory-checkpoint reason="pre-compaction" priority="critical" backend="obsidian">
CONTEXT IS ABOUT TO BE LOST. This is your last chance to save state. Complete ALL of the following before doing anything else:

1. UPDATE SESSION NOTE: Write current task, full progress with compact markers, blockers, "What Didn't Work" section, and detailed "Key Context for Recovery" to Sessions/{today} {project}.md

2. UPDATE HOT CACHE: Write .claude-state/{project-key}/recent.md with:
   - "Right Now" section reflecting exact current state
   - "Last verified" timestamp
   - "Recent Notes" table with last 10 touched notes
   - "Related Projects" if cross-project work happened
   - "Relationship Context" carrying forward interpersonal notes

3. UPDATE GLOBAL INDEX: Write .claude-state/global-index.md with any new topics, initiative status changes, or recent activity rows

4. UPDATE PROGRESS: Write Progress/{project}.md with current active/completed items

5. SAVE UNSAVED DECISIONS: Any decisions made but not yet written to Decisions/

Unsaved work: $EDITS edits across $FILES_COUNT files, $COMMITS commits since last save.
Vault root: $CLAUDE_ROOT
</memory-checkpoint>
PRECOMPACT_EOF
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
