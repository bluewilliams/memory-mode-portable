#!/bin/bash
# memory-doctor.sh - daily health check for the memory vault (v2.3)
#
# Finds the problems that make memory hard to recall, and fixes the ones that are safe to fix:
#   duplicates     People notes that share a name, an alias or a name prefix (Mitch / Mitchell)
#   broken-links   [[Claude/...]] links to notes that do not exist
#   no-summary     notes without a summary: (the dashboard and recall show bare file names)
#   breadcrumbs    Decisions, Analysis, Lessons and Runbooks notes missing from their _Index.md
#   big-caches     hot caches over 30 KB, and a global index over 40 KB
#   legacy-state   .claude-state folders with no project note, untouched for 60+ days
#   em-dashes      vault notes that still contain an em dash
#
# Usage:
#   memory-doctor.sh            Full report (markdown).
#   memory-doctor.sh --brief    A short report for the daily maintenance block.
#   memory-doctor.sh --fix      Run the safe fixes first: rebuild the recall index, split an oversized
#                               global index (backed up), then report what is left for judgment.
#
# Read-only unless --fix. It never merges, renames or deletes a note: that needs judgment.
# NOTE: Do NOT use `set -e`. A failure must never break a calling hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for c in "$SCRIPT_DIR/memory-common.sh" "$SCRIPT_DIR/../hooks/memory-common.sh" "$HOME/.claude/hooks/memory-common.sh"; do
    [ -f "$c" ] && { source "$c" 2>/dev/null; break; }
done
TOOLS_DIR="$SCRIPT_DIR"
[ -x "$TOOLS_DIR/memory-recall.sh" ] || TOOLS_DIR="$HOME/.claude/tools"

MODE="full"
FIX=""
for a in "$@"; do
    case "$a" in
        --brief) MODE="brief" ;;
        --fix) FIX=1 ;;
    esac
done

ROOT=$(get_claude_root 2>/dev/null)
STATE_DIR=$(get_state_dir 2>/dev/null)
[ -n "$ROOT" ] && [ -d "$ROOT" ] || exit 0
VAULT_PARENT=$(dirname "$ROOT")
CATALOG="$STATE_DIR/index/catalog.tsv"
ENTITIES="$STATE_DIR/index/entities.tsv"
NOW=$(date +%s)
FIXED=""

if [ -n "$FIX" ]; then
    "$TOOLS_DIR/memory-recall.sh" build >/dev/null 2>&1 && FIXED="$FIXED recall-index"
    gi="$STATE_DIR/global-index.md"
    if [ -f "$gi" ] && [ "$(wc -c < "$gi")" -gt 40960 ] && [ -x "$TOOLS_DIR/memory-index-split.sh" ]; then
        "$TOOLS_DIR/memory-index-split.sh" >/dev/null 2>&1 && FIXED="$FIXED index-split"
    fi
fi
[ -f "$CATALOG" ] || "$TOOLS_DIR/memory-recall.sh" build >/dev/null 2>&1

OUT=$(mktemp)
section() { # section <name> <one-line why> <lines...> (reads lines from stdin)
    local name="$1" why="$2" body count
    body=$(cat)
    [ -n "$body" ] || return 0
    count=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\n' "$name" "$count" "$why" >> "$OUT.summary"
    { echo "## $name ($count)"; echo "$why"; printf '%s\n' "$body" | sed 's/^/- /'; echo; } >> "$OUT"
}

# Duplicates: one term pointing at two People notes, or one single-word name that starts another name.
{
    [ -f "$ENTITIES" ] && awk -F'\t' '$2 == "person" { if (!(($1, $3) in s)) { s[$1, $3] = 1; n[$1]++; p[$1] = p[$1] (p[$1] ? " | " : "") $3 } }
        END { for (t in n) if (n[t] > 1) print "\"" t "\" -> " p[t] }' "$ENTITIES"
    ls "$ROOT/People" 2>/dev/null | grep -v '^_' | sed 's/\.md$//' | awk '
        { name[NR] = $0; low[NR] = tolower($0) }
        END { for (i = 1; i <= NR; i++) for (j = 1; j <= NR; j++) if (i != j && low[i] !~ / / && length(low[i]) >= 4 && index(low[j], low[i]) == 1) print name[i] " / " name[j] " (name prefix)" }'
} | sort -u | section "duplicates" "Possible duplicate People notes. Read both; merge only when they are the same person (keep the fuller note, move aliases, repoint links)."

# Broken links.
grep -rhoE '\[\[Claude/[^]|#]+' "$ROOT" --include='*.md' 2>/dev/null | sed 's/^\[\[//' | sort -u | while IFS= read -r target; do
    [ -e "$VAULT_PARENT/$target.md" ] || [ -e "$VAULT_PARENT/$target" ] || echo "$target"
done | head -40 | section "broken-links" "Links to notes that do not exist. Fix the link (renamed note) or write a stub."

# Notes with no summary (only the types that need one).
[ -f "$CATALOG" ] && awk -F'\t' '$2 ~ /^(session|decision|analysis|resource|brag|progress|lesson|runbook|project)$/ && $5 == "" { print $1 }' "$CATALOG" |
    head -40 | section "no-summary" "Notes without a summary: field. Add one line, so recall and the dashboard show what the note is."

# Breadcrumb gaps.
for d in Decisions Analysis Lessons Runbooks; do
    idx="$ROOT/$d/_Index.md"
    [ -f "$idx" ] || continue
    ls "$ROOT/$d" 2>/dev/null | grep '\.md$' | grep -v '^_' | sed 's/\.md$//' | while IFS= read -r n; do
        grep -qF "$n" "$idx" || echo "$d/$n"
    done
done | head -40 | section "breadcrumbs" "Notes missing from their folder _Index.md. Add a one-line entry."

# Big caches and index.
{
    for f in "$STATE_DIR"/*/recent.md; do
        [ -f "$f" ] || continue
        s=$(wc -c < "$f" | tr -d ' ')
        [ "$s" -gt 30720 ] && echo "$(basename "$(dirname "$f")")/recent.md is $((s / 1024)) KB: prune dormant blocks (Hot Cache Hygiene)"
    done
    gi="$STATE_DIR/global-index.md"
    [ -f "$gi" ] && s=$(wc -c < "$gi" | tr -d ' ') && [ "$s" -gt 40960 ] && echo "global-index.md is $((s / 1024)) KB: compress Topic Map rows to pointers, then run memory-index-split.sh"
} | section "big-caches" "Tier 0 and Tier 1 files must stay cheap to read."

# Legacy state folders.
for d in "$STATE_DIR"/*/; do
    k=$(basename "$d")
    case "$k" in index|sessions|backups) continue ;; esac
    [ -f "$ROOT/Projects/$k.md" ] && continue
    m=$(stat -f %m "$d" 2>/dev/null || stat -c %Y "$d" 2>/dev/null || echo "$NOW")
    [ $(( (NOW - m) / 86400 )) -ge 60 ] && echo "$k (no project note, untouched $(( (NOW - m) / 86400 ))d)"
done | head -40 | section "legacy-state" "State folders with no project. Move anything useful to the right project, then remove the folder."

# Em dashes.
grep -rlF '—' "$ROOT" --include='*.md' 2>/dev/null | grep -v '/.claude-state/' | sed "s|^$ROOT/||" | head -40 |
    section "em-dashes" "Vault notes with an em dash. Replace them when you touch the note."

if [ "$MODE" = "brief" ]; then
    if [ -f "$OUT.summary" ]; then
        printf 'Memory health:'
        awk -F'\t' '{ printf " %s %s,", $2, $1 }' "$OUT.summary" | sed 's/,$//'
        echo "."
        [ -n "$FIXED" ] && echo "Fixed automatically:$FIXED."
        awk '/^## /{ c = 0; print; next } { if (++c <= 4) print }' "$OUT"
    else
        echo "Memory health: no problems found.${FIXED:+ Fixed automatically:$FIXED.}"
    fi
else
    echo "# Memory doctor - $(date +%Y-%m-%d)"
    [ -n "$FIXED" ] && echo "Fixed automatically:$FIXED."
    echo
    if [ -s "$OUT" ]; then cat "$OUT"; else echo "No problems found."; fi
fi
rm -f "$OUT" "$OUT.summary"
exit 0
