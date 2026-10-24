#!/bin/bash
# memory-status.sh - Status hygiene scan for the Obsidian vault (v2.2)
#
# Lists notes whose status claims they are still open but nobody has touched them for a while:
#   - active / pending / in-progress / open older than ACTIVE_DAYS  -> "stale"
#   - living (hubs, progress notes) older than LIVING_DAYS           -> "dormant"
#   - stub older than STUB_DAYS                                      -> "old stub"
# Age comes from the `updated:` frontmatter field, then `date:`, then the file's modification time.
#
# Usage:
#   memory-status.sh                 # markdown report, every finding
#   memory-status.sh --brief 8       # one-line summary plus the 8 oldest findings
#   memory-status.sh --root <dir>    # scan another Claude root (default: from memory-config.json)
#
# Read-only: it never edits a note. Fast: one awk pass over the first lines of each note.
# NOTE: Do NOT use `set -e` — a failure must never break a calling hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/memory-common.sh" 2>/dev/null || true

ACTIVE_DAYS=30
LIVING_DAYS=45
STUB_DAYS=14
BRIEF=""
ROOT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --brief) BRIEF="${2:-8}"; shift 2 ;;
        --root) ROOT="$2"; shift 2 ;;
        --active-days) ACTIVE_DAYS="$2"; shift 2 ;;
        --living-days) LIVING_DAYS="$2"; shift 2 ;;
        --stub-days) STUB_DAYS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[ -n "$ROOT" ] || ROOT=$(get_claude_root 2>/dev/null) || true
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
    exit 0
fi

TODAY=$(date +%Y-%m-%d)

# Notes that carry a lifecycle status. Breadcrumbs (_*.md), backups and templates are skipped.
FILES=()
for dir in Analysis Decisions Progress Projects "Resources/References"; do
    [ -d "$ROOT/$dir" ] || continue
    while IFS= read -r f; do
        FILES+=("$f")
    done < <(find "$ROOT/$dir" -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null)
done
[ "${#FILES[@]}" -gt 0 ] || exit 0

# File modification dates, for notes with no date in their frontmatter: one stat call, GNU or BSD.
# GNU goes first: GNU stat -f means file system status and succeeds with the wrong output.
MTIMES=$(stat --printf '%y\t%n\n' "${FILES[@]}" 2>/dev/null | awk -F'\t' '{ print substr($1, 1, 10) "\t" $2 }') && [ -n "$MTIMES" ] \
    || MTIMES=$(stat -f '%Sm%t%N' -t %Y-%m-%d "${FILES[@]}" 2>/dev/null) \
    || MTIMES=$(for f in "${FILES[@]}"; do printf '%s\t%s\n' "$TODAY" "$f"; done)

# A project note is rarely edited while the project stays busy, so its age is the newest session for it.
# Session notes are named "YYYY-MM-DD <project>.md"; this lists "<project>\t<date>" for the newest of each.
SESSION_DATES=$(ls "$ROOT/Sessions" 2>/dev/null | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} .+\.md$/ {
    d = substr($0, 1, 10); p = substr($0, 12); sub(/\.md$/, "", p)
    if (!(p in latest) || d > latest[p]) latest[p] = d
} END { for (p in latest) print p "\t" latest[p] }')

FINDINGS=$({ printf '%s\n' "$SESSION_DATES" | sed 's/^/SESSION\t/'; printf '%s\n' "$MTIMES"; } | awk -F'\t' -v today="$TODAY" -v root="$ROOT/" \
    -v active_days="$ACTIVE_DAYS" -v living_days="$LIVING_DAYS" -v stub_days="$STUB_DAYS" '
function days(d,   y, m, dd, era, yoe, doy, doe) {
    # Days since the civil epoch for YYYY-MM-DD (Howard Hinnant algorithm), no date(1) needed.
    y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
    if (y < 1900 || m < 1 || m > 12 || dd < 1) return -1
    y -= (m <= 2)
    era = int((y >= 0 ? y : y - 399) / 400)
    yoe = y - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + dd - 1
    doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
    return era * 146097 + doe
}
function field(line,   v) {
    v = line; sub(/^[A-Za-z_]+:[ \t]*/, "", v); gsub(/^["\x27]|["\x27][ \t]*$/, "", v); return v
}
$1 == "SESSION" { session[$2] = $3; next }
{
    mtime = $1; file = $2
    status = ""; updated = ""; date = ""; summary = ""
    inside = 0; n = 0
    while ((getline line < file) > 0 && n < 60) {
        n++
        if (n == 1) { if (line !~ /^---/) break; inside = 1; continue }
        if (line ~ /^---/) break
        if (line ~ /^status:/) status = tolower(field(line))
        else if (line ~ /^updated:/) updated = substr(field(line), 1, 10)
        else if (line ~ /^date:/) date = substr(field(line), 1, 10)
        else if (line ~ /^summary:/) summary = field(line)
    }
    close(file)
    if (status == "") next
    ref = (updated != "" ? updated : (date != "" ? date : mtime))
    if (file ~ /\/Projects\//) {
        name = file; sub(/.*\/Projects\//, "", name); sub(/\.md$/, "", name)
        if ((name in session) && session[name] > ref) ref = session[name]
    }
    age = days(today) - days(ref)
    if (days(ref) < 0) next
    kind = ""
    if ((status == "active" || status == "pending" || status == "in-progress" || status == "open") && age > active_days) kind = "stale"
    else if (status == "living" && age > living_days) kind = "dormant"
    else if (status == "stub" && age > stub_days) kind = "old stub"
    if (kind == "") next
    rel = file; sub(root, "", rel); sub(/\.md$/, "", rel)
    if (length(summary) > 110) summary = substr(summary, 1, 107) "..."
    printf "%06d\t%s\t%s\t%s\t%s\n", age, kind, status, rel, summary
}' | LC_ALL=C sort -r)

COUNT=$(printf '%s' "$FINDINGS" | grep -c . 2>/dev/null) || COUNT=0
[ "$COUNT" -gt 0 ] || { [ -n "$BRIEF" ] || echo "Status hygiene: no stale, dormant or old stub notes."; exit 0; }

STALE=$(printf '%s\n' "$FINDINGS" | awk -F'\t' '$2=="stale"' | grep -c .)
DORMANT=$(printf '%s\n' "$FINDINGS" | awk -F'\t' '$2=="dormant"' | grep -c .)
STUBS=$(printf '%s\n' "$FINDINGS" | awk -F'\t' '$2=="old stub"' | grep -c .)

format_rows() {
    awk -F'\t' '{ age = $1 + 0; line = "- " age "d " $2 " (`" $3 "`) [[Claude/" $4 "]]"; if ($5 != "") line = line " - " $5; print line }'
}

if [ -n "$BRIEF" ]; then
    echo "Status hygiene: $COUNT notes need a status decision ($STALE stale active, $DORMANT dormant living, $STUBS old stubs). Oldest:"
    printf '%s\n' "$FINDINGS" | head -n "$BRIEF" | format_rows
else
    echo "# Status hygiene report - $TODAY"
    echo ""
    echo "$COUNT notes need a status decision: $STALE stale active (>${ACTIVE_DAYS}d), $DORMANT dormant living (>${LIVING_DAYS}d), $STUBS old stubs (>${STUB_DAYS}d)."
    echo "For each: confirm it is still open (touch \`updated:\`), or set completed / decided / superseded, or fill the stub."
    echo ""
    printf '%s\n' "$FINDINGS" | format_rows
fi

exit 0
