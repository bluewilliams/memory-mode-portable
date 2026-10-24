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
mkdir -p "$HOME/.claude/tools" "$HOME/.claude/user"
cp "$REPO"/tools/*.sh "$HOME/.claude/tools/"
chmod +x "$HOME/.claude/tools/"*.sh
H="$HOME/.claude/hooks"
T="$HOME/.claude/tools"

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
check "a plain request gets no recall cue" $(echo "$OUT" | grep -q 'memory-recall-cue'; [ $? -ne 0 ]; echo $?)
OUT=$(prompt B "Elijah hurt his arm at recess today"); check "a life event is noticed" $(echo "$OUT" | grep -q 'cues=".*life-event'; echo $?)
OUT=$(prompt B "the demo is next friday and I'm stressed about it"); check "a date ahead is noticed" $(echo "$OUT" | grep -q 'cues=".*dated'; echo $?)
check "a feeling is noticed" $(echo "$OUT" | grep -q 'cues=".*feeling'; echo $?)
check "the capture cue files by subject" $(echo "$OUT" | grep -q 'calendar.md'; echo $?)
OUT=$(prompt B "remember when we fixed the webhook?"); check "a reference to the past gets a recall cue" $(echo "$OUT" | grep -q '<memory-recall-cue>'; echo $?)

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
OUT=$(prompt F "hi again"); check "the weekly status nudge does not repeat" $(echo "$OUT" | grep -q 'weekly-status-hygiene'; [ $? -ne 0 ]; echo $?)

echo "precompact"
tool G Edit '{"file_path":"/x/p.ts"}'
OUT=$(jq -n '{session_id: "G"}' | "$H/memory-precompact.sh"); check "precompact prints the checklist" $(echo "$OUT" | grep -q 'pre-compaction'; echo $?)
check "precompact counts the session's edit" $(echo "$OUT" | grep -q 'Unsaved work: 1 edits'; echo $?)
check "precompact resets the session" $([ "$(jq -r .edits "$STATE/sessions/activity-G.json")" = "0" ]; echo $?)

echo "recall"
mkdir -p "$ROOT/People" "$ROOT/Lessons"
printf -- '---\ntype: person\nrole: Product Manager\naliases:\n  - Tony\n---\n# Tony Anderson\n' > "$ROOT/People/Tony Anderson.md"
printf -- '---\ntype: person\nsummary: "Engineer on the DeathStar Pod"\n---\n# Hash\n' > "$ROOT/People/Hash.md"
printf -- '---\ntype: person\nrole: President\n---\n# Mitch\n' > "$ROOT/People/Mitch.md"
printf -- '---\ntype: person\nrole: Head of Cloud\n---\n# Mitchell\n' > "$ROOT/People/Mitchell.md"
printf -- '---\ntype: person\nrole: QA lead\n---\n# Pat Quinn\n' > "$ROOT/People/Pat Quinn.md"
printf -- '---\ntype: project\nsummary: "Bedtime story app for kids"\n---\n# bedtime-buddy\n' > "$ROOT/Projects/bedtime-buddy.md"
printf -- '---\ntype: session\ndate: 2026-04-10\ntickets: [KA-6175]\nsummary: "Stripe webhook hardening for the launch"\n---\n# Session\n' > "$ROOT/Sessions/2026-04-10 bedtime-buddy.md"
printf -- '---\ntype: lesson\nsummary: "A pipe hides the exit code of the first command"\ntrigger: "When you check an exit status through a pipe"\n---\n# Pipe exit code\n' > "$ROOT/Lessons/pipe-exit-code.md"
printf -- '- **Name**: Blue\n' > "$HOME/.claude/user/profile.md"
printf '# Moments\n- 2026-10-16 Blue said the memory system is for Claude, to grow the relationship\n' > "$HOME/.claude/user/moments.md"
"$T/memory-recall.sh" build
check "the build writes the catalog and the entities" $([ -s "$STATE/index/catalog.tsv" ] && [ -s "$STATE/index/entities.tsv" ]; echo $?)
OUT=$(echo "ask Tony Anderson about KA-6175 on bedtime buddy" | "$T/memory-recall.sh" prompt)
check "a full name is recalled" $(echo "$OUT" | grep -q $'^tony anderson\tperson'; echo $?)
check "a ticket recalls its latest session" $(echo "$OUT" | grep -q $'^ka-6175\tticket\tSessions/2026-04-10 bedtime-buddy.md'; echo $?)
check "a project key matches with spaces for hyphens" $(echo "$OUT" | grep -q $'^bedtime buddy\tproject'; echo $?)
OUT=$(echo "and ask Pat" | "$T/memory-recall.sh" prompt)
check "a unique first name is recalled" $(echo "$OUT" | grep -q 'People/Pat Quinn.md'; echo $?)
OUT=$(echo "print the commit hash" | "$T/memory-recall.sh" prompt)
check "a lowercase common word is not a person" $(echo "$OUT" | grep -q 'Hash'; [ $? -ne 0 ]; echo $?)
OUT=$(echo "pair with Hash today" | "$T/memory-recall.sh" prompt)
check "a capitalized one-word name is a person" $(echo "$OUT" | grep -q 'People/Hash.md'; echo $?)
OUT=$(echo "Blue will review it" | "$T/memory-recall.sh" prompt)
check "the user is not recalled as a colleague" $([ -z "$OUT" ]; echo $?)
OUT=$("$T/memory-recall.sh" query pipe exit)
check "query finds a lesson by its summary" $(echo "$OUT" | grep -q 'Lessons/pipe-exit-code.md'; echo $?)
OUT=$("$T/memory-recall.sh" query relationship)
check "query finds a line in the user's moments" $(echo "$OUT" | grep -q 'moments.md'; echo $?)
OUT=$(prompt R "ask Tony Anderson about it"); check "the hook recalls a named colleague" $(echo "$OUT" | grep -q '<memory-recall>'; echo $?)
OUT=$(prompt R "Tony Anderson again"); check "the hook does not repeat a recall in one session" $(echo "$OUT" | grep -q 'memory-recall'; [ $? -ne 0 ]; echo $?)
OUT=$(prompt S "lets continue the stripe webhook hardening"); check "the first prompt recalls related notes by topic" $(echo "$OUT" | grep -q 'related (session)'; echo $?)

echo "doctor"
OUT=$("$T/memory-doctor.sh")
check "the doctor flags a name-prefix duplicate" $(echo "$OUT" | grep -q 'Mitch / Mitchell'; echo $?)
echo '[[Claude/Analysis/Missing Note]]' >> "$ROOT/Analysis/Old Investigation.md"
OUT=$("$T/memory-doctor.sh")
check "the doctor flags a broken link" $(echo "$OUT" | grep -q 'Claude/Analysis/Missing Note'; echo $?)
check "the doctor flags a note with no summary" $(echo "$OUT" | grep -q 'Projects/busy-project.md'; echo $?)
rm -f "$STATE/last-daily-maintenance" "$STATE/index/doctor-brief.txt"
prompt U "hello" > /dev/null
check "the first prompt of a work day stamps the daily pass" $([ "$(cat "$STATE/last-daily-maintenance")" = "$(date -v-4H +%Y-%m-%d 2>/dev/null || date -d '-4 hours' +%Y-%m-%d)" ]; echo $?)
for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$STATE/index/doctor-brief.txt" ] && break; sleep 0.5; done
OUT=$(prompt U "next"); check "the daily doctor report arrives on a later prompt" $(echo "$OUT" | grep -q 'memory-maintenance reason="daily-doctor"'; echo $?)
OUT=$(prompt U "again"); check "the daily report is shown once" $(echo "$OUT" | grep -q 'daily-doctor'; [ $? -ne 0 ]; echo $?)

echo "facts and topics"
printf -- '---\ntype: person\nrole: Product Manager\naliases:\n  - Tony\n---\n# Tony Anderson\n\n## Timeline\n- 2026-10-20 Tony broke his wrist skiing\n- 2026-09-01 Tony moved to the Platform team\n\n## Background\n- Likes long walks\n' > "$ROOT/People/Tony Anderson.md"
mkdir -p "$ROOT/Topics"
printf -- '---\ntype: topic\nsummary: "The family lake cabin"\n---\n# Cabin\n\n## Timeline\n- 2026-10-01 The dock needs new boards\n' > "$ROOT/Topics/Cabin.md"
"$T/memory-recall.sh" build
OUT=$("$T/memory-recall.sh" facts "People/Tony Anderson.md" 1)
check "facts returns the newest dated line" $([ "$OUT" = "2026-10-20 Tony broke his wrist skiing" ]; echo $?)
OUT=$("$T/memory-recall.sh" query wrist)
check "query finds a fact in a People note body" $(echo "$OUT" | grep -q 'fact 2026-10-20.*Tony Anderson'; echo $?)
for i in 1 2 3 4 5; do printf -- '---\ntype: analysis\nsummary: "Widget note %s"\n---\n# Widget %s\n' $i $i > "$ROOT/Analysis/Widget $i.md"; done
printf -- '---\ntype: decision\nsummary: "Quasar rollout plan"\n---\n# Quasar\n' > "$ROOT/Analysis/Quasar.md"
"$T/memory-recall.sh" build
OUT=$("$T/memory-recall.sh" query -n 1 widget quasar)
check "a rare term outranks a common one" $(echo "$OUT" | grep -q 'Quasar'; echo $?)
OUT=$("$T/memory-recall.sh" query walks)
check "query finds an undated bullet too" $(echo "$OUT" | grep -q 'Likes long walks'; echo $?)
OUT=$(echo "we should fix the cabin dock" | "$T/memory-recall.sh" prompt)
check "a topic is recalled by name" $(echo "$OUT" | grep -q $'^cabin\ttopic\tTopics/Cabin.md'; echo $?)
OUT=$(prompt V "ask Tony Anderson about the release")
check "a recalled person brings their latest facts" $(echo "$OUT" | grep -q 'Latest: 2026-10-20 Tony broke his wrist skiing'; echo $?)
prompt W "hello there" > /dev/null
OUT=$(prompt W "continue the stripe webhook hardening for the launch")
check "a later prompt with a strong topic match recalls related notes" $(echo "$OUT" | grep -q 'related (session)'; echo $?)
OUT=$(prompt W "and the webhook again")
check "a later prompt with a weak match recalls nothing extra" $(echo "$OUT" | grep -q 'related ('; [ $? -ne 0 ]; echo $?)

echo "calendar"
day() { date -v"$1"d +%Y-%m-%d 2>/dev/null || date -d "$1 days" +%Y-%m-%d; }
cat > "$HOME/.claude/user/calendar.md" <<EOF
# Calendar
- 1985-$(day +5 | cut -c6-) birthday: Nicole O'Connell -> [[People/Nicole O'Connell]]
- $(day +3) follow-up: Ask how Elijah's arm is healing
- $(day -2) event: Demo day
- $(day -40) trip: Old trip
- $(day +60) deadline: Far away
EOF
OUT=$("$T/memory-calendar.sh" due)
check "a follow-up in 3 days is due" $(echo "$OUT" | grep -q "in 3d .*follow-up: Ask how Elijah's arm"; echo $?)
check "a birthday shows the age, before the link" $(echo "$OUT" | grep -q "birthday: Nicole O'Connell (turns [0-9]*) -> \[\[People"; echo $?)
check "a passed event asks for the outcome" $(echo "$OUT" | grep -q "2d ago .*Demo day \[passed"; echo $?)
check "an item 60 days out is not due" $(echo "$OUT" | grep -q 'Far away'; [ $? -ne 0 ]; echo $?)
check "an item 40 days past is not due" $(echo "$OUT" | grep -q 'Old trip'; [ $? -ne 0 ]; echo $?)
OUT=$("$T/memory-calendar.sh" stale)
check "an item 40 days past is stale" $(echo "$OUT" | grep -q 'Old trip'; echo $?)
check "a yearly item is never stale" $(echo "$OUT" | grep -q 'Nicole'; [ $? -ne 0 ]; echo $?)
OUT=$(prompt X "hi"); check "the first prompt gets the upcoming block" $(echo "$OUT" | grep -q '<memory-upcoming>'; echo $?)
OUT=$(prompt X "hi again"); check "the upcoming block shows once per work day" $(echo "$OUT" | grep -q 'memory-upcoming'; [ $? -ne 0 ]; echo $?)

echo "capture sweep"
TR="$TMP/transcripts"; mkdir -p "$TR/-proj-a" "$TR/-proj-game"
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
u() { jq -cn --arg t "$1" --arg c "$2" --arg ts "$NOWISO" --argjson side "${3:-false}" '{type:"user", isSidechain:$side, timestamp:$ts, cwd:$c, message:{role:"user", content:$t}}'; }
{ u "Elijah hurt his arm at recess today" /proj/a
  u "<command-name>/clear</command-name>" /proj/a
  u "a subagent prompt that is long enough" /proj/a true
  u "ok" /proj/a
  u "this part is off the record please" /proj/a
  u "a secret plan after off the record" /proj/a; } > "$TR/-proj-a/s1.jsonl"
u "game talk that is long enough to keep" /home/AdventureVault > "$TR/-proj-game/s2.jsonl"
jq '. + {sweep: {exclude: ["AdventureVault"]}}' "$HOME/.claude/memory-config.json" > "$TMP/c" && mv "$TMP/c" "$HOME/.claude/memory-config.json"
OUT=$(MEMORY_TRANSCRIPTS="$TR" "$T/memory-sweep.sh" collect)
P="$HOME/.claude/.memory-sweep/pending.md"
check "the sweep reports what it collected" $(echo "$OUT" | grep -q '^1 prompts from 1 sessions'; echo $?)
check "the sweep keeps a real prompt" $(grep -q 'Elijah hurt his arm' "$P"; echo $?)
check "the sweep skips command wrappers, short prompts and subagents" $(grep -qE 'command-name|^- ok$|subagent prompt' "$P"; [ $? -ne 0 ]; echo $?)
check "the sweep drops everything from off the record on" $(grep -q 'secret plan\|off the record' "$P"; [ $? -ne 0 ]; echo $?)
check "the sweep skips an excluded working directory" $(grep -q 'game talk' "$P"; [ $? -ne 0 ]; echo $?)
OUT=$("$T/memory-doctor.sh" --brief); check "the doctor reports a waiting sweep" $(echo "$OUT" | grep -q 'capture-sweep'; echo $?)
"$T/memory-sweep.sh" done
check "done clears the sweep" $([ ! -f "$P" ] && [ -s "$HOME/.claude/.memory-sweep/last" ]; echo $?)
OUT=$(MEMORY_TRANSCRIPTS="$TR" "$T/memory-sweep.sh" collect)
check "the next sweep starts where the last one ended" $([ -z "$OUT" ] && [ ! -f "$P" ]; echo $?)

echo "default backend"
cat > "$HOME/.claude/memory-config.json" <<'EOF'
{ "version": "2.2.0", "backend": "default" }
EOF
OUT=$(prompt H "hello"); check "the default backend still gets the clock" $(echo "$OUT" | grep -q 'memory-clock'; echo $?)
check "the default backend skips the vault status scan" $(echo "$OUT" | grep -q 'memory-maintenance'; [ $? -ne 0 ]; echo $?)

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
