#!/bin/bash
# memory-sweep.sh - the daily capture sweep (v2.4)
#
# Capture during a conversation is a judgment call, and some calls get missed. Once a day this collects
# what the user typed in every Claude Code session since the last sweep, so a background pass can read
# it and capture what was worth keeping and never made it into memory.
#
#   memory-sweep.sh collect   Write the user's prompts since the last sweep to pending.md; print a summary.
#   memory-sweep.sh status    Print the summary line when a sweep is waiting.
#   memory-sweep.sh done      Mark the sweep finished (the next one starts where this one ended).
#
# Files: ~/.claude/.memory-sweep/ (outside the vault, beside the transcripts it reads).
# Skipped: subagent turns, slash-command wrappers, very short prompts, everything after "off the record"
# in a session, and sessions whose working directory contains a string listed in memory-config.json
# under "sweep": { "exclude": [...] } (for example a vault that keeps its own memory).
#
# NOTE: Do NOT use `set -e`. The doctor runs this in the background and must never fail loudly.

SWEEP_DIR="$HOME/.claude/.memory-sweep"
PENDING="$SWEEP_DIR/pending.md"
STAMP="$SWEEP_DIR/last"
TRANSCRIPTS="${MEMORY_TRANSCRIPTS:-$HOME/.claude/projects}"
CONFIG_FILE="$HOME/.claude/memory-config.json"
FIRST_RUN_LOOKBACK_SEC=172800

iso_utc() { date -u -r "$1" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%S; }

cmd_collect() {
    mkdir -p "$SWEEP_DIR" || return 1
    local now since since_iso excludes count sessions
    now=$(date +%s)
    since=$(cat "$STAMP" 2>/dev/null | tr -cd '0-9')
    [ -n "$since" ] || since=$((now - FIRST_RUN_LOOKBACK_SEC))
    since_iso=$(iso_utc "$since")
    excludes=$(jq -c '.sweep.exclude // []' "$CONFIG_FILE" 2>/dev/null) || excludes='[]'
    [ -n "$excludes" ] || excludes='[]'
    touch -t "$(date -r "$since" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$since" +%Y%m%d%H%M.%S)" "$SWEEP_DIR/.since" 2>/dev/null

    {
        echo "# Capture sweep: prompts since $(date -r "$since" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$since" '+%Y-%m-%d %H:%M')"
        echo
        find "$TRANSCRIPTS" -maxdepth 2 -name '*.jsonl' -newer "$SWEEP_DIR/.since" 2>/dev/null | sort |
        while IFS= read -r f; do
            jq -r --arg since "$since_iso" --argjson ex "$excludes" -s '
                [ .[] | select(.type == "user" and (.isSidechain | not) and ((.timestamp // "") > ($since + ".999Z")))
                  | {ts: .timestamp, cwd: (.cwd // ""), text: (.message.content | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end)} ]
                | map(select((.text | length) >= 15 and (.text | test("^\\s*(<|Caveat:|\\[Image: source:)") | not)))
                | if length == 0 then empty else . end
                | if (.[0].cwd as $c | $ex | any(. as $e | $c | contains($e))) then empty else . end
                | (map(.text | test("off the record"; "i")) | index(true)) as $otr
                | (if $otr == null then . else .[0:$otr] end)
                | if length == 0 then empty else
                    "## " + (.[0].cwd | split("/") | last) + " - " + (.[0].ts[0:16] | sub("T"; " ")) + " UTC (" + (input_filename | split("/") | last | .[0:8]) + ")\n"
                    + (map("- " + (.text | gsub("\n+"; " ") | .[0:1500])) | join("\n")) + "\n"
                  end' "$f" 2>/dev/null
        done
    } > "$PENDING.tmp"
    count=$(grep -c '^- ' "$PENDING.tmp" 2>/dev/null)
    sessions=$(grep -c '^## ' "$PENDING.tmp" 2>/dev/null)
    if [ "${count:-0}" -eq 0 ]; then
        rm -f "$PENDING.tmp" "$PENDING"
        echo "$now" > "$STAMP"
        return 0
    fi
    mv "$PENDING.tmp" "$PENDING"
    echo "$now" > "$SWEEP_DIR/collected"
    cmd_status
}

cmd_status() {
    [ -s "$PENDING" ] || return 0
    echo "$(grep -c '^- ' "$PENDING") prompts from $(grep -c '^## ' "$PENDING") sessions wait in $PENDING"
}

cmd_done() {
    local t
    t=$(cat "$SWEEP_DIR/collected" 2>/dev/null | tr -cd '0-9')
    [ -n "$t" ] || t=$(date +%s)
    echo "$t" > "$STAMP"
    rm -f "$PENDING" "$SWEEP_DIR/collected"
}

case "$1" in
    collect) cmd_collect ;;
    status) cmd_status ;;
    done) cmd_done ;;
    *) sed -n '2,16p' "$0"; exit 1 ;;
esac
