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

# v2.2: Claude Code pipes {session_id, prompt, ...} on stdin. Read it once; every part below is optional.
INPUT=$(cat 2>/dev/null) || INPUT=""
if [ -n "$INPUT" ] && ! printf '%s' "$INPUT" | jq empty 2>/dev/null; then INPUT=""; fi
SESSION_ID=$(session_id_from_json "$INPUT" 2>/dev/null) || SESSION_ID=""
PROMPT_TEXT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null | head -c 4000) || PROMPT_TEXT=""
STATE_FILE=$(activity_file_for "$STATE_DIR" "$SESSION_ID" 2>/dev/null) || STATE_FILE="$STATE_DIR/activity.json"
NOW=$(date +%s)

# --- v2.2 clock: the model only knows the date, not the time or how long ago the last prompt was. ---
# Every prompt gets a one-line local time. The first prompt of a session, a gap of 2h or more, and a new
# work day get a fuller block, so a session that resumes the next morning starts a new dated session note.
emit_clock() {
    local clock_dir="$STATE_DIR/sessions" clock_file last_epoch last_workday workday hour daypart now_txt gap gap_txt reason=""
    mkdir -p "$clock_dir" 2>/dev/null || return 0
    clock_file="$clock_dir/clock-${SESSION_ID:-shared}.json"
    workday=$(workday_for_epoch "$NOW" 2>/dev/null) || return 0
    hour=$(format_epoch "$NOW" "%H" 2>/dev/null) || return 0
    daypart=$(daypart_for_hour "$hour")
    now_txt=$(format_epoch "$NOW" "%a %Y-%m-%d %H:%M %Z" 2>/dev/null)
    last_epoch=0; last_workday=""
    if [ -f "$clock_file" ] && jq empty "$clock_file" 2>/dev/null; then
        last_epoch=$(jq -r '.last_prompt // 0' "$clock_file" 2>/dev/null) || last_epoch=0
        last_workday=$(jq -r '.workday // ""' "$clock_file" 2>/dev/null) || last_workday=""
    fi
    gap=$((NOW - last_epoch))
    if [ "$last_epoch" -eq 0 ]; then reason="session-start"
    elif [ -n "$last_workday" ] && [ "$last_workday" != "$workday" ]; then reason="new-workday"
    elif [ "$gap" -ge 7200 ]; then reason="long-gap"
    fi
    jq -n --argjson t "$NOW" --arg w "$workday" '{last_prompt: $t, workday: $w}' > "$clock_file.tmp" 2>/dev/null && mv "$clock_file.tmp" "$clock_file"

    if [ -z "$reason" ]; then
        echo "<memory-clock now=\"$now_txt\" daypart=\"$daypart\" workday=\"$workday\"/>"
        return 0
    fi
    gap_txt=""
    [ "$last_epoch" -gt 0 ] && gap_txt=" Last prompt in this session: $(human_gap "$gap") ago ($(format_epoch "$last_epoch" "%a %H:%M"))."
    local guidance=""
    case "$reason" in
        session-start) guidance="Use workday $workday for today's session note." ;;
        new-workday) guidance="A new work day started since the last prompt (was $last_workday). Write today's work to a new session note dated $workday, threaded with continues: to the previous one; do not append to the old day's note. Greet accordingly." ;;
        long-gap) guidance="The user was away for a while. Re-anchor on the hot cache Right Now before continuing." ;;
    esac
    [ "$daypart" = "late evening" ] || [ "$daypart" = "late night" ] && guidance="$guidance It is $daypart for the user: keep answers tight, and offer to park long work for tomorrow."
    echo "<memory-clock reason=\"$reason\" now=\"$now_txt\" daypart=\"$daypart\" workday=\"$workday\">Local time: $now_txt ($daypart). Work day: $workday (work before 0${WORKDAY_BOUNDARY_HOUR}:00 counts as the previous day).$gap_txt $guidance</memory-clock>"
}

# --- v2.2 learning cues: notice things worth remembering about the user and their world. ---
emit_learn() {
    [ -n "$PROMPT_TEXT" ] || return 0
    local text cues=""
    text=$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')
    if printf '%s' "$text" | grep -Eq "(^|[^a-z])(i prefer|i'd prefer|i like|i don't like|i do not like|i hate|i love|please always|please never|always use|never use|from now on|going forward|in the future|remember (that|this)|don't ever|stop doing|i want you to|i'd rather)"; then cues="$cues preference"; fi
    if printf '%s' "$text" | grep -Eq "(^|[^a-z])my (wife|husband|partner|son|daughter|kids?|children|family|mom|dad|brother|sister|dog|cat|birthday|vacation|manager|boss)|(^|[^a-z])i'm (out|off|on vacation|on pto|traveling|sick)|(^|[^a-z])(birthday|anniversary|pto|time off)([^a-z]|$)"; then cues="$cues personal"; fi
    if printf '%s' "$PROMPT_TEXT" | grep -Eq "(with|from|for|ask|tell|told|asked|meeting with|working with|talk to|ping) [A-Z][a-z]{2,}( [A-Z][a-z]{2,})?"; then cues="$cues person"; fi
    [ -n "$cues" ] || return 0
    cues=$(echo "$cues" | sed 's/^ //')
    echo "<memory-learn cues=\"$cues\">This prompt may hold something worth remembering. Capture it silently where it belongs, without asking unless it is ambiguous: preferences and corrections -> ~/.claude/user/preferences.md or feedback.md (and People/_Preferences.md); personal context the user shared -> ~/.claude/user/profile.md and People/{name}.md; a named colleague -> check People/ and update or create their note (ask once who they are if unknown). Never store secrets or anything the user asked to forget. If nothing new is here, ignore this.</memory-learn>"
}

# --- v2.2 weekly status hygiene: surface notes whose status no longer tells the truth. ---
emit_status_hygiene() {
    local stamp="$STATE_DIR/last-status-scan" last=0 report
    [ "$(get_backend 2>/dev/null)" = "obsidian" ] || return 0
    [ -x "$SCRIPT_DIR/memory-status.sh" ] || return 0
    [ -f "$stamp" ] && last=$(cat "$stamp" 2>/dev/null | tr -cd '0-9')
    [ -n "$last" ] || last=0
    [ $((NOW - last)) -ge 604800 ] || return 0
    echo "$NOW" > "$stamp" 2>/dev/null || return 0
    report=$("$SCRIPT_DIR/memory-status.sh" --brief 8 2>/dev/null) || return 0
    [ -n "$report" ] || return 0
    printf '<memory-maintenance reason="weekly-status-hygiene">%s\nAt a natural pause, offer the user a short status pass: for each note, confirm it is still open (touch updated:), or set completed / decided / superseded. Full list: ~/.claude/hooks/memory-status.sh</memory-maintenance>\n' "$report"
}

# Per-session files from sessions that ended more than 7 days ago are removed now and then.
if [ $((NOW % 20)) -eq 0 ] && [ -d "$STATE_DIR/sessions" ]; then
    find "$STATE_DIR/sessions" -type f -name '*.json' -mtime +7 -delete 2>/dev/null || true
fi

emit_clock 2>/dev/null || true
emit_learn 2>/dev/null || true
emit_status_hygiene 2>/dev/null || true

# Tunable thresholds
CYCLES_THRESHOLD=3              # nudge every N cycles if activity present
TIME_THRESHOLD_SEC=900          # 15 min - time-based nudge
MIN_NUDGE_GAP_SEC=300           # 5 min minimum between non-commit nudges
PURE_CYCLES_THRESHOLD=5         # nudge every N cycles when no file activity

# A session's activity file starts empty, so long conversations without edits still get their nudge.
if [ ! -f "$STATE_FILE" ]; then
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    jq -n --argjson now "$NOW" "$INIT_ACTIVITY_JSON | .last_nudge = \$now" > "$STATE_FILE" 2>/dev/null || exit 0
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
