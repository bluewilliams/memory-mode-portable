#!/bin/bash
# memory-calendar.sh - dated memory: birthdays, events, deadlines and follow-ups (v2.4)
#
#   memory-calendar.sh due [days]     Items in the next N days (default 14; yearly items get 7 more days
#                                     of lead time) and one-time items that passed in the last 30 days.
#   memory-calendar.sh stale [days]   One-time items more than N days past (default 14): close them out.
#   memory-calendar.sh list           Every item, soonest first.
#
# File: ~/.claude/user/calendar.md, one item per line:
#   - YYYY-MM-DD kind: text -> [[optional link]]
# Yearly kinds (birthday, anniversary) repeat on the month and day; the year is the original year,
# so a birthday line can carry the birth year. Every other kind (event, trip, deadline, appointment,
# follow-up, reminder) happens once and is removed when it is done.
#
# NOTE: Do NOT use `set -e`. The due mode runs inside a hook and must never fail loudly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for c in "$SCRIPT_DIR/memory-common.sh" "$SCRIPT_DIR/../hooks/memory-common.sh" "$HOME/.claude/hooks/memory-common.sh"; do
    [ -f "$c" ] && { source "$c" 2>/dev/null; break; }
done

CALENDAR="${MEMORY_CALENDAR:-$HOME/.claude/user/calendar.md}"
TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(epoch_for_date "$TODAY")
YEAR=${TODAY%%-*}

is_yearly() { case "$1" in birthday|anniversary) return 0 ;; *) return 1 ;; esac; }

# Prints "days<TAB>date<TAB>kind<TAB>text" for every item; days is relative to today (negative = past).
items() {
    [ -f "$CALENDAR" ] && [ -n "$TODAY_EPOCH" ] || return 0
    sed -nE 's/^[ ]*[-*] ([0-9]{4}-[0-9]{2}-[0-9]{2}) ([A-Za-z-]+): (.*)$/\1	\2	\3/p' "$CALENDAR" |
    while IFS=$'\t' read -r d kind text; do
        kind=$(printf '%s' "$kind" | tr '[:upper:]' '[:lower:]')
        when="$d"
        if is_yearly "$kind"; then
            md=${d#*-}
            when="$YEAR-$md"
            e=$(epoch_for_date "$when") || e=$(epoch_for_date "$YEAR-${md%-*}-28")
            if [ -n "$e" ] && [ "$e" -lt "$TODAY_EPOCH" ]; then
                when="$((YEAR + 1))-$md"
                e=$(epoch_for_date "$when") || e=$(epoch_for_date "$((YEAR + 1))-${md%-*}-28")
            fi
            orig=${d%%-*}
            occ=${when%%-*}
            if [ "$orig" -gt 1900 ] && [ "$orig" -lt "$occ" ]; then
                n=$((occ - orig))
                link=""
                case "$text" in *" -> "*) link=" -> ${text#* -> }"; text=${text%% -> *} ;; esac
                [ "$kind" = "birthday" ] && text="$text (turns $n)$link" || text="$text ($n years)$link"
            fi
        else
            e=$(epoch_for_date "$d")
        fi
        [ -n "$e" ] || continue
        printf '%s\t%s\t%s\t%s\n' "$(( (e - TODAY_EPOCH) / 86400 ))" "$when" "$kind" "$text"
    done | sort -t$'\t' -k1,1n
}

label() {
    local days="$1"
    if [ "$days" -eq 0 ]; then echo "today"
    elif [ "$days" -eq 1 ]; then echo "tomorrow"
    elif [ "$days" -gt 1 ]; then echo "in ${days}d"
    elif [ "$days" -eq -1 ]; then echo "yesterday"
    else echo "$(( -days ))d ago"
    fi
}

cmd_due() {
    local window="${1:-14}"
    items | while IFS=$'\t' read -r days when kind text; do
        if is_yearly "$kind"; then
            [ "$days" -le $((window + 7)) ] || continue
        else
            [ "$days" -le "$window" ] && [ "$days" -ge -30 ] || continue
        fi
        note=""
        [ "$days" -lt 0 ] && note=" [passed: ask how it went, record the outcome, then remove the line]"
        printf -- '- %s (%s) %s: %s%s\n' "$(label "$days")" "$when" "$kind" "$text" "$note"
    done
}

cmd_stale() {
    local after="${1:-14}"
    items | while IFS=$'\t' read -r days when kind text; do
        is_yearly "$kind" && continue
        [ "$days" -lt $(( -after )) ] && printf '%s %s: %s (%s)\n' "$when" "$kind" "$text" "$(label "$days")"
    done
}

cmd_list() {
    items | while IFS=$'\t' read -r days when kind text; do
        printf -- '- %s (%s) %s: %s\n' "$(label "$days")" "$when" "$kind" "$text"
    done
}

case "$1" in
    due) shift; cmd_due "$@" ;;
    stale) shift; cmd_stale "$@" ;;
    list) cmd_list ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
esac
