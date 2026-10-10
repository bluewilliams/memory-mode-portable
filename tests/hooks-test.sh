#!/bin/bash
# hooks-test.sh - behavior tests for the memory hooks, run in a throwaway HOME and vault.
# Usage: ./tests/hooks-test.sh        (exit 0 when every check passes)
# Never touches the real ~/.claude or vault.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/.claude/hooks"
cp "$REPO"/hooks/*.sh "$HOME/.claude/hooks/"
chmod +x "$HOME/.claude/hooks/"*.sh
H="$HOME/.claude/hooks"

VAULT="$TMP/vault"
ROOT="$VAULT/Claude"
mkdir -p "$ROOT/Analysis" "$ROOT/Projects" "$ROOT/Sessions" "$ROOT/.claude-state"
cat > "$HOME/.claude/memory-config.json" <<EOF
{ "version": "2.2.0", "backend": "obsidian", "obsidian": { "vaultPath": "$VAULT", "basePath": "Claude" } }
EOF
STATE="$ROOT/.claude-state"

PASS=0; FAIL=0
check() { # check <name> <condition-exit-code>
    if [ "$2" -eq 0 ]; then PASS=$((PASS + 1)); echo "  ok   $1"; else FAIL=$((FAIL + 1)); echo "  FAIL $1"; fi
}
prompt() { # prompt <session> <text>
    jq -n --arg s "$1" --arg p "$2" '{session_id: $s, prompt: $p, hook_event_name: "UserPromptSubmit"}' | "$H/memory-nudge.sh"
}
tool() { # tool <session> <tool> <json-input>
    jq -n --arg s "$1" --arg t "$2" --argjson i "$3" '{session_id: $s, tool_name: $t, tool_input: $i}' | "$H/memory-tracker.sh"
}

echo "clock"
OUT=$(prompt A "hello"); check "first prompt of a session gets a session-start clock" $(echo "$OUT" | grep -q 'memory-clock reason="session-start"'; echo $?)
OUT=$(prompt A "next"); check "later prompts get a one-line clock" $(echo "$OUT" | grep -q '<memory-clock now=.*/>'; echo $?)
check "the one-line clock has no reason" $(echo "$OUT" | grep -q 'reason="session-start"'; [ $? -ne 0 ]; echo $?)
jq '.workday = "2000-01-01"' "$STATE/sessions/clock-A.json" > "$TMP/c" && mv "$TMP/c" "$STATE/sessions/clock-A.json"
OUT=$(prompt A "good morning"); check "a new work day is announced" $(echo "$OUT" | grep -q 'reason="new-workday"'; echo $?)
check "the new work day names the previous day" $(echo "$OUT" | grep -q 'was 2000-01-01'; echo $?)
jq '.last_prompt = (.last_prompt - 9000)' "$STATE/sessions/clock-A.json" > "$TMP/c" && mv "$TMP/c" "$STATE/sessions/clock-A.json"
OUT=$(prompt A "back"); check "a gap of 2h or more is announced" $(echo "$OUT" | grep -q 'reason="long-gap"'; echo $?)

echo "learning cues"
OUT=$(prompt B "From now on I prefer short answers"); check "a preference is noticed" $(echo "$OUT" | grep -q 'memory-learn cues="preference'; echo $?)
OUT=$(prompt B "I have a meeting with Tony Anderson at 10"); check "a named colleague is noticed" $(echo "$OUT" | grep -q 'cues=".*person'; echo $?)
OUT=$(prompt B "my daughter has a recital tonight"); check "personal context is noticed" $(echo "$OUT" | grep -q 'cues=".*personal'; echo $?)
OUT=$(prompt B "run the tests please"); check "a plain request gets no learning cue" $(echo "$OUT" | grep -q 'memory-learn'; [ $? -ne 0 ]; echo $?)

echo "per-session activity"
tool C Edit '{"file_path":"/x/a.ts"}'
tool D Edit '{"file_path":"/x/b.ts"}'
tool D Edit '{"file_path":"/x/c.ts"}'
check "session C counts its own edit" $([ "$(jq -r .edits "$STATE/sessions/activity-C.json")" = "1" ]; echo $?)
check "session D counts its own edits" $([ "$(jq -r .edits "$STATE/sessions/activity-D.json")" = "2" ]; echo $?)
tool C Bash '{"command":"git commit -m \"x\""}'
OUT=$(prompt C "next"); check "a commit nudges its own session" $(echo "$OUT" | grep -q 'reason="post-commit"'; echo $?)
check "the nudge reset session C only" $([ "$(jq -r .edits "$STATE/sessions/activity-C.json")" = "0" ] && [ "$(jq -r .edits "$STATE/sessions/activity-D.json")" = "2" ]; echo $?)
OUT=$(prompt D "next"); check "another session is not nudged for that commit" $(echo "$OUT" | grep -q 'post-commit'; [ $? -ne 0 ]; echo $?)

echo "pure conversation"
for i in 1 2 3 4; do prompt E "talk $i" > /dev/null; done
jq '.last_nudge = 0' "$STATE/sessions/activity-E.json" > "$TMP/c" && mv "$TMP/c" "$STATE/sessions/activity-E.json"
OUT=$(prompt E "talk 5"); check "five cycles with no edits get the self-assess nudge" $(echo "$OUT" | grep -q 'reason="pure-conversation"'; echo $?)

echo "legacy input"
OUT=$(echo '' | "$H/memory-nudge.sh"); check "empty stdin still exits 0" $?
OUT=$(echo 'not json' | "$H/memory-nudge.sh"); check "invalid stdin still exits 0" $?
echo '{"tool_name":"Edit","tool_input":{"file_path":"/x/z"}}' | "$H/memory-tracker.sh"
check "no session id falls back to activity.json" $([ "$(jq -r .edits "$STATE/activity.json")" = "1" ]; echo $?)

echo "status hygiene"
cat > "$ROOT/Analysis/Old Investigation.md" <<'EOF'
---
type: analysis
date: 2020-01-01
status: active
summary: "An old open investigation"
---
# Old
EOF
TODAY=$(date +%Y-%m-%d)
cat > "$ROOT/Analysis/Fresh Hub.md" <<EOF
---
type: analysis
date: 2020-01-01
updated: $TODAY
status: living
---
# Fresh
EOF
cat > "$ROOT/Projects/busy-project.md" <<'EOF'
---
type: project
date: 2020-01-01
status: active
---
EOF
touch "$ROOT/Sessions/$TODAY busy-project.md"
OUT=$("$H/memory-status.sh"); check "an old active note is flagged stale" $(echo "$OUT" | grep -q 'stale (`active`) \[\[Claude/Analysis/Old Investigation\]\]'; echo $?)
check "a living note touched today is not flagged" $(echo "$OUT" | grep -q 'Fresh Hub'; [ $? -ne 0 ]; echo $?)
check "a project with a session today is not flagged" $(echo "$OUT" | grep -q 'busy-project'; [ $? -ne 0 ]; echo $?)
rm -f "$STATE/last-status-scan"
OUT=$(prompt F "hi"); check "the weekly status nudge fires once" $(echo "$OUT" | grep -q 'memory-maintenance reason="weekly-status-hygiene"'; echo $?)
OUT=$(prompt F "hi again"); check "the weekly status nudge does not repeat" $(echo "$OUT" | grep -q 'memory-maintenance'; [ $? -ne 0 ]; echo $?)

echo "precompact"
tool G Edit '{"file_path":"/x/p.ts"}'
OUT=$(jq -n '{session_id: "G"}' | "$H/memory-precompact.sh"); check "precompact prints the checklist" $(echo "$OUT" | grep -q 'pre-compaction'; echo $?)
check "precompact counts the session's edit" $(echo "$OUT" | grep -q 'Unsaved work: 1 edits'; echo $?)
check "precompact resets the session" $([ "$(jq -r .edits "$STATE/sessions/activity-G.json")" = "0" ]; echo $?)

echo "default backend"
cat > "$HOME/.claude/memory-config.json" <<'EOF'
{ "version": "2.2.0", "backend": "default" }
EOF
OUT=$(prompt H "hello"); check "the default backend still gets the clock" $(echo "$OUT" | grep -q 'memory-clock'; echo $?)
check "the default backend skips the vault status scan" $(echo "$OUT" | grep -q 'memory-maintenance'; [ $? -ne 0 ]; echo $?)

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
