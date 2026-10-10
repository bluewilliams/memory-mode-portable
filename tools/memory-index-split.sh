#!/bin/bash
# memory-index-split.sh - keep the Tier 0 global index small without losing anything (v2.2)
#
# The global index is read at every session start, so it must stay a short pointer file. Over time
# "Recent Across All Projects" and long Topic Map rows grow it past 100 KB. This tool moves text out,
# verbatim, into shards under .claude-state/index/:
#
#   index/timeline/YYYY-MM.md   Recent rows older than --keep-days (default 14), newest first, one file
#                               per month. The month files ARE the long-term timeline.
#   index/topic-detail.md       The full text of Topic Map rows longer than --topic-limit characters
#                               (default 400). The index keeps the row's opening and a pointer.
#
# Safe by design: a timestamped backup of the index goes to index/backups/ first; moved text is copied
# before the index is rewritten; running it again moves only rows that aged out since the last run.
#
# Usage:
#   tools/memory-index-split.sh [--dry-run] [--keep-days 14] [--topic-limit 400] [--index <path>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SCRIPT_DIR/../hooks/memory-common.sh"
[ -f "$COMMON" ] || COMMON="$HOME/.claude/hooks/memory-common.sh"
source "$COMMON" 2>/dev/null || { echo "memory-common.sh not found" >&2; exit 1; }

DRY_RUN=""
KEEP_DAYS=14
TOPIC_LIMIT=400
INDEX=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --keep-days) KEEP_DAYS="$2"; shift 2 ;;
        --topic-limit) TOPIC_LIMIT="$2"; shift 2 ;;
        --index) INDEX="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$INDEX" ]; then
    STATE_DIR=$(get_state_dir)
    INDEX="$STATE_DIR/global-index.md"
fi
[ -f "$INDEX" ] || { echo "no global index at $INDEX" >&2; exit 1; }
SHARDS="$(dirname "$INDEX")/index"
CUTOFF=$(format_epoch $(($(date +%s) - KEEP_DAYS * 86400)) "%Y-%m-%d")
STAMP=$(date +%Y%m%d-%H%M%S)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Pass 1: split the index into what stays, the aged Recent rows, and the long Topic Map rows.
# A Recent row starts with "- YYYY-MM-DD" or "| YYYY-MM-DD"; table rows are normalized to list rows.
awk -v cutoff="$CUTOFF" -v limit="$TOPIC_LIMIT" -v out="$WORK" '
BEGIN { section = "" }
/^## / {
    section = $0
    print > (out "/index.md")
    if (section ~ /^## Recent/) recent_header = 1
    next
}
section ~ /^## Recent/ {
    if (match($0, /^[-|] *[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
        d = substr($0, RSTART, RLENGTH); sub(/^[-|] */, "", d)
        if (d < cutoff) {
            row = $0
            if (row ~ /^\|/) {
                n = split(row, cell, "|")
                for (i = 1; i <= n; i++) { gsub(/^ +| +$/, "", cell[i]) }
                row = "- " cell[2] " **" cell[3] "** - " cell[4]
                for (i = 5; i < n; i++) if (cell[i] != "") row = row " - " cell[i]
            }
            print substr(d, 1, 7) "\t" d "\t" row > (out "/aged.tsv")
            moved_recent++
            next
        }
    }
    if ($0 ~ /^\| *(Date|-+) *\|/) next   # drop a table header with no rows left under it
    print > (out "/index.md")
    next
}
section ~ /^## (Topic Map|Active Initiatives)/ && length($0) > limit && $0 !~ /^#/ && index($0, "(full: index/topic-detail.md") == 0 {
    key = $0
    if (index(key, " -> ") > 0) key = substr(key, 1, index(key, " -> ") - 1)
    else if (index(key, " → ") > 0) key = substr(key, 1, index(key, " → ") - 1)
    else key = substr(key, 1, 80)
    gsub(/[#\[\]|]/, "", key); sub(/^[-* ]+/, "", key); sub(/ +$/, "", key)
    print key "\t" $0 > (out "/topics.tsv")
    short = substr($0, 1, limit - 120)
    cut = 0
    for (i = length(short); i > 120; i--) if (substr(short, i, 2) == ". ") { cut = i; break }
    if (cut > 0) short = substr(short, 1, cut)
    print short " … (full: index/topic-detail.md, \"" key "\")" > (out "/index.md")
    moved_topics++
    next
}
{ print > (out "/index.md") }
END { printf "%d\t%d\n", moved_recent + 0, moved_topics + 0 > (out "/counts") }
' "$INDEX"

read -r MOVED_RECENT MOVED_TOPICS < "$WORK/counts"
BEFORE=$(wc -c < "$INDEX" | tr -d ' ')
AFTER=$(wc -c < "$WORK/index.md" | tr -d ' ')
echo "Global index: $BEFORE bytes -> $AFTER bytes. Recent rows older than $CUTOFF to move: $MOVED_RECENT. Long topic rows to shard: $MOVED_TOPICS."
if [ -n "$DRY_RUN" ]; then
    [ -f "$WORK/aged.tsv" ] && cut -f1 "$WORK/aged.tsv" | sort | uniq -c | sed 's/^/  timeline /'
    exit 0
fi
[ "$MOVED_RECENT" -gt 0 ] || [ "$MOVED_TOPICS" -gt 0 ] || { echo "Nothing to move."; exit 0; }

mkdir -p "$SHARDS/timeline" "$SHARDS/backups" || exit 1
cp "$INDEX" "$SHARDS/backups/global-index-$STAMP.md" || { echo "backup failed; index unchanged" >&2; exit 1; }

# Pass 2: merge aged rows into their month files, newest first, with no duplicate rows.
if [ -f "$WORK/aged.tsv" ]; then
    for month in $(cut -f1 "$WORK/aged.tsv" | sort -u); do
        file="$SHARDS/timeline/$month.md"
        {
            [ -f "$file" ] && grep -E '^[-|] *[0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" | awk '{ d = $0; sub(/^[-|] */, "", d); print substr(d, 1, 10) "\t" $0 }'
            awk -F'\t' -v m="$month" '$1 == m { print $2 "\t" $3 }' "$WORK/aged.tsv"
        } | LC_ALL=C sort -t$'\t' -k1,1r -s | awk -F'\t' '!seen[$2]++ { print $2 }' > "$WORK/rows"
        {
            echo "---"
            echo "type: index"
            echo "date: $month-01"
            echo "tags:"
            echo "  - index"
            echo "summary: \"Activity timeline for $month, moved out of the global index Recent section\""
            echo "---"
            echo "# Timeline $month"
            echo ""
            echo "Recent rows for $month, newest first. Moved verbatim from \`.claude-state/global-index.md\` by \`memory-index-split.sh\`."
            echo ""
            cat "$WORK/rows"
        } > "$file.tmp" && mv "$file.tmp" "$file"
    done
fi

# Pass 3: append or refresh each long topic's full text in topic-detail.md.
if [ -f "$WORK/topics.tsv" ]; then
    detail="$SHARDS/topic-detail.md"
    if [ ! -f "$detail" ]; then
        printf -- '---\ntype: index\ndate: %s\ntags:\n  - index\nsummary: "Full text of long Topic Map rows; the global index keeps a short pointer to each"\n---\n# Topic Detail\n\nFull Topic Map rows, keyed by topic. The global index keeps the opening of each row and points here.\n' "$(date +%Y-%m-%d)" > "$detail"
    fi
    while IFS=$'\t' read -r key row; do
        awk -v key="## $key" 'BEGIN { skip = 0 } $0 == key { skip = 1; next } /^## / { skip = 0 } !skip' "$detail" > "$detail.tmp" && mv "$detail.tmp" "$detail"
        printf '\n## %s\n%s\n' "$key" "$row" >> "$detail"
    done < "$WORK/topics.tsv"
fi

# Pass 4: point the Recent section at the timeline, once.
if ! grep -q 'index/timeline/' "$WORK/index.md"; then
    awk '{ print } /^## Recent/ && !done { print "Older activity: `.claude-state/index/timeline/YYYY-MM.md` (one file per month, newest first). This section keeps the last two weeks."; done = 1 }' "$WORK/index.md" > "$WORK/index2.md" && mv "$WORK/index2.md" "$WORK/index.md"
fi

# Verify nothing was lost before replacing the index: every moved row must exist in a shard.
LOST=0
if [ -f "$WORK/aged.tsv" ]; then
    while IFS=$'\t' read -r month _ row; do
        grep -qF -- "$row" "$SHARDS/timeline/$month.md" || LOST=$((LOST + 1))
    done < "$WORK/aged.tsv"
fi
if [ -f "$WORK/topics.tsv" ]; then
    while IFS=$'\t' read -r _ row; do
        grep -qF -- "$row" "$SHARDS/topic-detail.md" || LOST=$((LOST + 1))
    done < "$WORK/topics.tsv"
fi
if [ "$LOST" -gt 0 ]; then
    echo "ABORTED: $LOST moved rows were not found in the shards. The index is unchanged; shards may hold partial copies." >&2
    exit 1
fi

cp "$WORK/index.md" "$INDEX"
echo "Done. Backup: index/backups/global-index-$STAMP.md. Timeline: index/timeline/. Topic detail: index/topic-detail.md."
