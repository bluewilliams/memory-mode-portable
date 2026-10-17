#!/bin/bash
# memory-recall.sh - associative recall over the memory vault.
#
#   memory-recall.sh build             Rebuild the catalog and the entity index.
#   memory-recall.sh query [-n N] [-t] <terms...>
#                                      Rank notes and memory lines by the terms (12 results; -t prints TSV).
#   memory-recall.sh prompt            Read a prompt on stdin and print the known entities it names.
#   memory-recall.sh stale             Exit 0 when the catalog needs a rebuild.
#
# Files (in the state dir, index/):
#   catalog.tsv   path, type, date, title, summary (one row per note, plus one row per line of the user's memory files)
#   entities.tsv  term (lowercase), kind, path, summary (people, projects, tickets)
#
# NOTE: Do NOT use `set -e`. The prompt mode runs inside a hook and must never fail loudly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for c in "$SCRIPT_DIR/memory-common.sh" "$SCRIPT_DIR/../hooks/memory-common.sh" "$HOME/.claude/hooks/memory-common.sh"; do
    [ -f "$c" ] && { source "$c" 2>/dev/null; break; }
done

ROOT=$(get_claude_root 2>/dev/null)
STATE_DIR=$(get_state_dir 2>/dev/null)
INDEX_DIR="$STATE_DIR/index"
CATALOG="$INDEX_DIR/catalog.tsv"
ENTITIES="$INDEX_DIR/entities.tsv"
USER_DIR="$HOME/.claude/user"
STALE_AFTER_SEC=21600

user_name() {
    sed -n 's/^- \*\*Name\*\*: *//p' "$USER_DIR/profile.md" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]' | tr -d '\r'
}

# One row per note: frontmatter type, date, summary (or role, or trigger), aliases, tickets, and the H1.
scan_notes() {
    find "$ROOT" -type f -name '*.md' -not -path '*/.claude-state/*' -not -path '*/_Templates/*' -not -path '*/.obsidian/*' -print0 2>/dev/null |
    xargs -0 awk -v root="$ROOT/" '
        function flush() {
            if (path == "") return
            if (summary == "") summary = role
            if (summary == "") summary = trigger
            gsub(/\t/, " ", summary); gsub(/\t/, " ", title)
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", path, type, date, title, summary, aliases, tickets
        }
        function clean(v) { sub(/^[^:]*:[ ]*/, "", v); gsub(/^["\x27]|["\x27]$/, "", v); return v }
        FNR == 1 {
            flush()
            path = FILENAME; sub(root, "", path)
            type = ""; date = ""; title = ""; summary = ""; role = ""; trigger = ""; aliases = ""; tickets = ""
            infm = ($0 == "---"); list = ""
            if (infm) next
        }
        infm && $0 == "---" { infm = 0; next }
        infm {
            if ($0 ~ /^[A-Za-z_]+:/) {
                list = ""
                if ($0 ~ /^type:/) type = clean($0)
                else if ($0 ~ /^date:/) date = clean($0)
                else if ($0 ~ /^summary:/) summary = clean($0)
                else if ($0 ~ /^role:/) role = clean($0)
                else if ($0 ~ /^trigger:/) trigger = clean($0)
                else if ($0 ~ /^aliases:/) { list = "aliases"; v = clean($0); gsub(/[\[\]]/, "", v); if (v != "") aliases = v }
                else if ($0 ~ /^tickets:/) { list = "tickets"; v = clean($0); gsub(/[\[\] ]/, "", v); if (v != "") tickets = v }
            } else if (list != "" && $0 ~ /^[ ]*- /) {
                v = $0; sub(/^[ ]*- [ ]*/, "", v); gsub(/^["\x27]|["\x27]$/, "", v)
                if (list == "aliases") aliases = (aliases == "" ? v : aliases "," v)
                else tickets = (tickets == "" ? v : tickets "," v)
            }
            next
        }
        title == "" && /^# / { title = substr($0, 3); flush(); path = ""; nextfile }
        END { flush() }
    ' 2>/dev/null
}

cmd_build() {
    [ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "memory-recall: no memory root found" >&2; return 1; }
    mkdir -p "$INDEX_DIR" || return 1
    local tmp_notes="$INDEX_DIR/.notes.$$" tmp_cat="$INDEX_DIR/.catalog.$$" tmp_ent="$INDEX_DIR/.entities.$$" me
    me=$(user_name)
    scan_notes > "$tmp_notes"

    # Catalog: every note, then every dated line of the user's own memory files.
    cut -f1-5 "$tmp_notes" > "$tmp_cat"
    for f in moments observations profile; do
        [ -f "$USER_DIR/$f.md" ] || continue
        awk -v p="~/.claude/user/$f.md" -v t="user-$f" '
            /^#/ { h = $0; sub(/^#+ */, "", h); next }
            /^[ ]*[-*] / || /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
                line = $0; sub(/^[ ]*[-*] /, "", line); gsub(/\t/, " ", line)
                d = ""; if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) d = substr(line, RSTART, 10)
                printf "%s\t%s\t%s\t%s\t%s\n", p, t, d, h, line
            }' "$USER_DIR/$f.md" >> "$tmp_cat"
    done

    # Entities: people (file name, aliases, a unique first name), projects (key), tickets (latest session).
    awk -F'\t' -v me="$me" '
        function add(term, kind, path, summary) {
            term = tolower(term); gsub(/^ +| +$/, "", term)
            if (length(term) < 3 || term == me || term ~ /^(the|and|your name)$/) return
            if (seen[term SUBSEP path]++) return
            printf "%s\t%s\t%s\t%s\n", term, kind, path, summary
        }
        $1 ~ /^People\// && $1 !~ /\/_/ {
            name = $1; sub(/^People\//, "", name); sub(/\.md$/, "", name)
            if (tolower(name) == me || tolower(name) ~ "^" me " ") next
            add(name, "person", $1, $5)
            n = split($6, al, ",")
            for (i = 1; i <= n; i++) add(al[i], "person", $1, $5)
            split(name, w, " "); if (w[2] != "") { first[tolower(w[1])]++; fpath[tolower(w[1])] = $1; fsum[tolower(w[1])] = $5 }
        }
        $1 ~ /^Projects\// && $1 !~ /\/_/ {
            key = $1; sub(/^Projects\//, "", key); sub(/\.md$/, "", key)
            add(key, "project", $1, $5)
            if (key ~ /-/) { spaced = key; gsub(/-/, " ", spaced); add(spaced, "project", $1, $5) }
        }
        $2 == "session" && $7 != "" {
            n = split($7, tk, ",")
            for (i = 1; i <= n; i++) if (tk[i] ~ /^[A-Z][A-Z0-9]+-[0-9]+$/ && $3 > tdate[tk[i]]) { tdate[tk[i]] = $3; tpath[tk[i]] = $1; tsum[tk[i]] = $5 }
        }
        END {
            for (f in first) if (first[f] == 1) add(f, "person", fpath[f], fsum[f])
            for (t in tpath) add(t, "ticket", tpath[t], "last worked " tdate[t] ": " tsum[t])
        }
    ' "$tmp_notes" > "$tmp_ent"

    mv "$tmp_cat" "$CATALOG" && mv "$tmp_ent" "$ENTITIES"
    rm -f "$tmp_notes"
    return 0
}

cmd_stale() {
    [ -f "$CATALOG" ] && [ -f "$ENTITIES" ] || return 0
    local age
    age=$(( $(date +%s) - $(stat -f %m "$CATALOG" 2>/dev/null || stat -c %Y "$CATALOG" 2>/dev/null || echo 0) ))
    [ "$age" -ge "$STALE_AFTER_SEC" ] && return 0
    [ -n "$(find "$ROOT" "$USER_DIR" -name '*.md' -newer "$CATALOG" -not -path '*/.claude-state/*' -print -quit 2>/dev/null)" ] && return 0
    return 1
}

# Score = terms found in the title and summary (title and path hits count double), newest first on ties.
cmd_query() {
    local limit=12 tsv=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -n) limit="$2"; shift 2 ;;
            -t) tsv=1; shift ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || { echo "usage: memory-recall.sh query [-n N] [-t] <terms...>" >&2; return 1; }
    cmd_stale && cmd_build
    [ -f "$CATALOG" ] || return 1
    TERMS="$*" awk -F'\t' '
        BEGIN { n = split(tolower(ENVIRON["TERMS"]), t, /[ ,]+/) }
        {
            hay = tolower($4 " " $5); key = tolower($1 " " $4); s = 0
            for (i = 1; i <= n; i++) if (length(t[i]) > 1 && index(hay, t[i])) s += (index(key, t[i]) ? 2 : 1)
            if (s > 0) printf "%d\t%s\t%s\t%s\t%s\n", s, $3, $1, $2, ($5 != "" ? $5 : $4)
        }' "$CATALOG" | sort -t$'\t' -k1,1nr -k2,2r | head -n "$limit" |
        awk -F'\t' -v tsv="$tsv" '{ if (tsv) print; else printf "- [%s%s] %s - %s\n", $4, ($2 != "" ? " " $2 : ""), $3, $5 }'
}

# Entities named in the prompt, matched on word boundaries. Prints "term<TAB>kind<TAB>path<TAB>summary".
# A one-word person name must be capitalized in the prompt, so "hash" in "the commit hash" is not Hash.
cmd_prompt() {
    [ -f "$ENTITIES" ] || return 0
    P="$(head -c 4000)" awk -F'\t' '
        BEGIN {
            raw = " " ENVIRON["P"] " "; gsub(/[^A-Za-z0-9 _.\x27-]/, " ", raw); gsub(/\x27s /, " ", raw)
            p = tolower(raw)
        }
        $2 == "person" && $1 !~ / / {
            cap = toupper(substr($1, 1, 1)) substr($1, 2)
            if (match(raw, "[^A-Za-z0-9_-]" cap "[^A-Za-z0-9_]")) print
            next
        }
        {
            i = index(p, $1)
            while (i > 0) {
                before = substr(p, i - 1, 1); after = substr(p, i + length($1), 1)
                if (before !~ /[a-z0-9_-]/ && after !~ /[a-z0-9_]/) { print; break }
                rest = substr(p, i + 1); j = index(rest, $1); i = (j > 0 ? i + j : 0)
            }
        }' "$ENTITIES"
}

case "$1" in
    build) cmd_build ;;
    query) shift; cmd_query "$@" ;;
    prompt) cmd_prompt ;;
    stale) cmd_stale ;;
    *) sed -n '2,12p' "$0"; exit 1 ;;
esac
