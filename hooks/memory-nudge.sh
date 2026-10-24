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
# NOTE: Do NOT use `set -e`: jq failures must not kill the script.

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
    CLOCK_REASON="$reason"
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

# --- v2.4 capture and recall cues. Capture is a judgment made on every prompt (see MEMORY.md > Capture
# Reflex); these cues only add weight when a prompt clearly holds something worth keeping or points back
# to something said before. ---
emit_learn() {
    [ -n "$PROMPT_TEXT" ] || return 0
    local text cues="" b="(^|[^a-z])"
    text=$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')
    if printf '%s' "$text" | grep -Eq "$b(i prefer|i'd prefer|i like|i don't like|i do not like|i hate|i love|please always|please never|always use|never use|from now on|going forward|in the future|remember (that|this)|don't ever|stop doing|i want you to|i'd rather)"; then cues="$cues preference"; fi
    if printf '%s' "$text" | grep -Eq "${b}my (wife|husband|partner|girlfriend|boyfriend|son|sons|daughter|daughters|kids?|children|family|mom|dad|mother|father|parents|brother|sister|grandma|grandpa|friend|dog|cat|birthday|vacation|manager|boss|team|house|car|health)|${b}i'm (out|off|on vacation|on pto|traveling|sick)|$b(birthday|anniversary|pto|time off)([^a-z]|\$)"; then cues="$cues personal"; fi
    if printf '%s' "$text" | grep -Eq "$b(hurt|injur|broke|sprain|stitches|cast|sick|fever|flu|covid|surgery|hospital|er visit|doctor|dentist|diagnos|pregnan|new baby|was born|died|passed away|funeral|wedding|engaged|divorce|moving|moved|new house|new job|quit|fired|laid off|let go|promoted|promotion|got hired|resign|retir|graduat|first day|started school)"; then cues="$cues life-event"; fi
    if printf '%s' "$text" | grep -Eq "$b(excited|nervous|worried|stressed|anxious|frustrated|exhausted|burned out|burnt out|proud|thrilled|bummed|upset|overwhelmed|relieved|can't wait|dreading)([^a-z]|\$)"; then cues="$cues feeling"; fi
    if printf '%s' "$text" | grep -Eq "$b(tomorrow|tonight|this weekend|next (week|month|year|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday)|on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(january|february|march|april|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\.? [0-9]{1,2}([^0-9]|\$)|deadline|due (on|by)|party|trip|flight|concert|recital|appointment|conference|interview|demo day|launch day)"; then cues="$cues dated"; fi
    if printf '%s' "$text" | grep -Eq "$b(i'm (thinking about|planning|going to|considering)|we're (planning|going to|thinking about)|i want to (start|learn|build|try|get)|my goal|someday|eventually i)"; then cues="$cues plan"; fi
    if printf '%s' "$PROMPT_TEXT" | grep -Eq "(with|from|for|ask|tell|told|asked|meeting with|working with|talk to|ping) [A-Z][a-z]{2,}( [A-Z][a-z]{2,})?"; then cues="$cues person"; fi
    if printf '%s' "$text" | grep -Eq "$b(remember (when|the|that|how|what)|last time|the other day|we (talked|discussed|decided|said|agreed|did) |you (said|told me|mentioned|suggested|recommended)|as (i|we) (said|mentioned|discussed)|like before|did i (tell|mention)|what was (the|that)|do you (know|remember)|what do you (know|remember))"; then
        echo "<memory-recall-cue>This prompt points back to something from before. Answer from memory, not a guess: run ~/.claude/tools/memory-recall.sh query with its key terms first, and open the session notes for that time when the detail matters.</memory-recall-cue>"
    fi
    [ -n "$cues" ] || return 0
    cues=$(echo "$cues" | sed 's/^ //')
    echo "<memory-learn cues=\"$cues\">This prompt may hold something worth remembering. If a good colleague would still remember it in a month, capture it silently, filed by what it is about: a person -> People/{name}.md (a dated line under ## Timeline; create the note if needed); the user's life -> ~/.claude/user/profile.md, Current Chapter or moments.md; a preference or correction -> preferences.md; a date ahead, or a check-in worth making later -> ~/.claude/user/calendar.md (- YYYY-MM-DD kind: text, with an exact date); any other subject that will come up again -> Topics/{subject}.md; project work -> the session note. Replace an old value instead of adding a second one. Never store secrets or anything the user asked to forget.</memory-learn>"
}

# --- v2.4 calendar: once per work day in each session, birthdays, events and follow-ups that are close. ---
emit_upcoming() {
    [ -x "$TOOLS_DIR/memory-calendar.sh" ] || return 0
    local stamp="$STATE_DIR/sessions/upcoming-${SESSION_ID:-shared}.txt" today due
    today=$(workday_for_epoch "$NOW" 2>/dev/null) || return 0
    [ "$(cat "$stamp" 2>/dev/null)" = "$today" ] && return 0
    mkdir -p "$STATE_DIR/sessions" 2>/dev/null
    echo "$today" > "$stamp" 2>/dev/null || return 0
    due=$("$TOOLS_DIR/memory-calendar.sh" due 2>/dev/null) || return 0
    [ -n "$due" ] || return 0
    printf '<memory-upcoming>Dates you are holding for the user (~/.claude/user/calendar.md). Bring one up when it is natural or useful: a birthday a week out, a check-in on something that just passed. Do not recite the list.\n%s\n</memory-upcoming>\n' "$due"
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

# --- v2.3 tools: recall and the daily doctor live in ~/.claude/tools (or ../tools in the repo). ---
TOOLS_DIR="$HOME/.claude/tools"
[ -x "$TOOLS_DIR/memory-recall.sh" ] || TOOLS_DIR="$SCRIPT_DIR/../tools"

# Run a command detached, so a slow rebuild never delays the prompt. One run at a time per lock name.
run_detached() {
    local lock="$STATE_DIR/index/.lock-$1"; shift
    mkdir -p "$STATE_DIR/index" 2>/dev/null || return 0
    # A lock older than 10 minutes belongs to a run that died.
    [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
    mkdir "$lock" 2>/dev/null || return 0
    nohup bash -c '"$@"; rmdir "$0"' "$lock" "$@" >/dev/null 2>&1 &
}

# --- v2.3 associative recall: name a person, project or ticket, and what you know about it comes back. ---
emit_recall() {
    [ -n "$PROMPT_TEXT" ] && [ -x "$TOOLS_DIR/memory-recall.sh" ] || return 0
    "$TOOLS_DIR/memory-recall.sh" stale 2>/dev/null && run_detached recall "$TOOLS_DIR/memory-recall.sh" build
    local seen="$STATE_DIR/sessions/recall-${SESSION_ID:-shared}.txt" hits lines path facts
    mkdir -p "$STATE_DIR/sessions" 2>/dev/null
    touch "$seen" 2>/dev/null || return 0
    hits=$(printf '%s' "$PROMPT_TEXT" | "$TOOLS_DIR/memory-recall.sh" prompt 2>/dev/null |
        awk -F'\t' -v seen="$seen" 'BEGIN { while ((getline l < seen) > 0) s[l] = 1 } !($3 in s) && !($3 in out) { out[$3] = 1; print }' | head -5)
    # Every prompt also gets the notes most related to its topic. The first prompt of a session (or after a
    # long gap) casts a wider net; later prompts need a stronger match, so only clear hits come back.
    local words related min=3 max=2
    if [ "$CLOCK_REASON" = "session-start" ] || [ "$CLOCK_REASON" = "long-gap" ] || [ "$CLOCK_REASON" = "new-workday" ]; then min=2; max=4; fi
    words=$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' ' ' | tr ' ' '\n' |
        grep -Ev '^(.{0,3}|about|after|again|also|because|before|being|could|does|doing|from|have|into|just|like|make|more|need|please|really|should|some|that|their|them|then|there|these|they|thing|things|this|want|what|when|where|which|while|will|with|would|your|yours)$' | awk '!s[$0]++' | head -8 | tr '\n' ' ')
    if [ -n "$words" ]; then
        related=$("$TOOLS_DIR/memory-recall.sh" query -t -n 15 $words 2>/dev/null | HITS="$hits" awk -F'\t' -v seen="$seen" -v min="$min" -v max="$max" '
            BEGIN { while ((getline l < seen) > 0) s[l] = 1; n = split(ENVIRON["HITS"], h, "\n"); for (i = 1; i <= n; i++) { split(h[i], f, "\t"); s[f[3]] = 1 } }
            $1 >= min && $3 !~ /^~\// && $4 != "fact" && !($3 in s) { s[$3] = 1; printf "related\t%s\t%s\t%s\n", $4, $3, $5; if (++c == max) exit }')
        [ -n "$related" ] && hits="$hits${hits:+
}$related"
    fi
    [ -n "$hits" ] || return 0
    printf '%s\n' "$hits" | cut -f3 >> "$seen"
    # A recalled person or topic brings its newest dated facts along, so recent news is not missed.
    lines=$(printf '%s\n' "$hits" | while IFS=$'\t' read -r term kind path summary; do
        [ ${#summary} -gt 220 ] && summary="${summary:0:217}..."
        facts=""
        if [ "$kind" = "person" ] || [ "$kind" = "topic" ]; then
            facts=$("$TOOLS_DIR/memory-recall.sh" facts "$path" 2 2>/dev/null | cut -c1-160 | paste -sd ';' - | sed 's/;/; /g')
        fi
        printf -- '- %s (%s): %s%s -> %s\n' "$term" "$kind" "$summary" "${facts:+ Latest: $facts}" "$path"
    done)
    printf '<memory-recall>You already know these from earlier work. Use them as your own recollection, and open the note when the detail matters:\n%s\n</memory-recall>\n' "$lines"
}

# --- v2.3 daily maintenance: once per work day, the doctor runs in the background and reports next prompt. ---
emit_daily_maintenance() {
    [ "$(get_backend 2>/dev/null)" = "obsidian" ] && [ -x "$TOOLS_DIR/memory-doctor.sh" ] || return 0
    local stamp="$STATE_DIR/last-daily-maintenance" report="$STATE_DIR/index/doctor-brief.txt" today
    today=$(workday_for_epoch "$NOW" 2>/dev/null) || return 0
    if [ "$(cat "$stamp" 2>/dev/null)" != "$today" ]; then
        echo "$today" > "$stamp" 2>/dev/null || return 0
        rm -f "$report" 2>/dev/null
        run_detached doctor bash -c '"$1" --fix --brief > "$2.tmp" && mv "$2.tmp" "$2"' _ "$TOOLS_DIR/memory-doctor.sh" "$report"
        return 0
    fi
    [ -s "$report" ] || return 0
    if grep -q 'no problems found' "$report"; then rm -f "$report"; return 0; fi
    printf '<memory-maintenance reason="daily-doctor">%s\nAt a natural pause (or now, if the user is idle or the task is small), do the daily memory pass in Vault Maintenance > Daily: delegate it to a background subagent when one is available, so the user is not kept waiting. Full report: ~/.claude/tools/memory-doctor.sh</memory-maintenance>\n' "$(cat "$report")"
    mv "$report" "$report.done" 2>/dev/null
}

# Per-session files from sessions that ended more than 7 days ago are removed now and then.
if [ $((NOW % 20)) -eq 0 ] && [ -d "$STATE_DIR/sessions" ]; then
    find "$STATE_DIR/sessions" -type f -name '*.json' -mtime +7 -delete 2>/dev/null || true
fi

emit_clock 2>/dev/null || true
emit_learn 2>/dev/null || true
emit_recall 2>/dev/null || true
emit_upcoming 2>/dev/null || true
emit_daily_maintenance 2>/dev/null || true
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
            NUDGE="<memory-checkpoint reason=\"cycle-checkpoint\" backend=\"obsidian\">$NEW_CYCLES conversation cycles with $EDITS edit(s) across $FILES_COUNT file(s) since your last memory save. If anything worth capturing happened - decisions, analysis findings, progress, new context, or something you learned about the user or a colleague - update the active session note in Sessions/ and the hot cache in .claude-state/{project}/recent.md (and profile.md, moments.md or People/ for what you learned). If nothing is worth saving, acknowledge silently and continue.</memory-checkpoint>"
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
        NUDGE="<memory-checkpoint reason=\"pure-conversation\" backend=\"obsidian\">$NEW_CYCLES conversation cycles with no file activity. Self-assess: did any decisions, analysis findings, context shifts, preferences, or interesting moments (a story, an opinion, news from the user's life or the org) emerge in this discussion? Capture moments in ~/.claude/user/moments.md and changes in profile.md Current Chapter. If yes, update the active session note in Sessions/ and the hot cache in .claude-state/{project}/recent.md. Also scan for new people mentioned - if anyone lacks a note in People/, use AskUserQuestion to learn about them. If nothing is worth saving, acknowledge silently and continue.</memory-checkpoint>"
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
