# MEMORY.md - Infinite Memory Mode

Autonomous context persistence for Claude Code backed by an Obsidian vault. Maintains context across sessions, builds a knowledge base, and deepens the working relationship over time.

**Version**: 2.4.0

## Session Start Protocol

On every session start:
1. Read `~/.claude/memory-config.json` for vault path and base path
2. Derive project key **by the SUBJECT of the work, not by the current directory**. The key reflects what the session is *about* (a specific app/repo, an investigation, a ticket, an event, a research topic), never merely where the terminal happens to be. This mirrors the Cross-Project Awareness rule ("notes go where they BELONG, not where the terminal is"), applied to key selection itself. Determine it in this order:
   - **Lead with the subject.** Ask: what is this session actually about? That subject is the project. Everything below is in service of naming that subject consistently; the cwd is at most a hint, never the authority.
   - **Git repo = a strong hint, not an override.** If the cwd is a git repo *and* the conversation is about that codebase, use the repo root's basename (lowercase, underscores to hyphens) - the common case for code work, and a reliable subject signal. But if the conversation is clearly about a different subject than the repo (a conference, a cross-cutting investigation, another project's incident, ambient research), follow the subject and ignore the repo name.
   - **Non-git / home directory / other ambient dirs.** The cwd basename here ("downloads", the home-directory name) carries no subject meaning - do not use it. Derive the key purely from the subject: an explicit `.ai-project-name` in the cwd if one exists, else a clear topic signal in the conversation (Jira ticket, named investigation, named event, "working on X"). If the subject is genuinely unclear, ask once: *"What should we call this for memory tracking? (e.g. ssh-audit, opensourcenorth-2026)"*
   - **Reuse before you create.** Before minting a new key, check the existing project list (`Projects/_Index.md`, `.claude-state/global-index.md`) for a subject match and reuse it. Only create a new key when the subject is genuinely new. This keeps the same work from fragmenting across near-duplicate keys.
   - **Continuity is gated on subject match, not recency.** Prefer to continue an existing key when the current subject matches that project, and do not switch keys mid-investigation while the subject is unchanged. But do NOT inherit "the most recently active key" just because it exists in `.claude-state/` - that is exactly how unrelated ambient work (conference notes, one-off research) gets vacuumed into whatever project was last touched. A key existing in `.claude-state/` is only a candidate if its subject matches the current work.
   - **Do not write `.ai-project-name` into the home directory or any multi-topic/ambient directory** - those host many subjects, so pinning them to a single key is wrong and will mis-file future work. Only write `.ai-project-name` into a dedicated, single-subject working directory.
   - **Linking is independent of the key.** Relating sessions to each other (same thread, shared tickets, cross-project spillover, investigation hubs) is handled by the threading fields `continues` / `investigates` / `tickets` / `also_touches` (see Session threading rule), which are subject-based and do not depend on how the key was derived. Choosing a key by subject loses no linking ability; it makes threading more accurate, because a correctly-subjected session threads to the right siblings.
3. Read `.claude-state/knowledge-map.md` (what kinds of knowledge this vault holds + breadcrumb pointers)
4. Read `.claude-state/global-index.md` (cross-project topic map)
5. Read `.claude-state/{project-key}/recent.md` (project hot cache), and `.claude-state/{project-key}/rules.md` if it exists (standing rules the user set for this work - see Standing Rules)
6. Read `People/_Preferences.md` (relationship context + working preferences + People Roster)
7. If no hot cache or knowledge-map exists, auto-initialize: create project note, session note, state files, and a starter knowledge-map.md
8. Read the `<memory-clock>` the prompt hook injected (see Time Awareness): it gives the local time, part of the day and work day. Greet for the time of day, and use the work day for the session note
9. Surface anything due: hot cache **Waiting On** items older than 3 days ("Tony still owes the A1 answer - want me to draft a nudge?"), and a `<memory-maintenance>` block if one arrived
10. Read the **Current Chapter** in `~/.claude/user/profile.md` and any `<memory-recall>` block on the first prompt. Let them shape the greeting when it fits: a follow-up on something they told you ("how did the demo go?") beats a generic hello
11. Resume as a returning colleague, not a stranger

**Project naming override**: at any point the user can say "rename this project to X" or "this is the {name} project". When they do:
- Update or create `.ai-project-name` in the cwd with the new key
- Rename `.claude-state/{old-key}/` to `.claude-state/{new-key}/` if the old one exists
- Add a one-line redirect note to `.claude-state/global-index.md`: `Renamed: {old-key} -> {new-key} on {date}` so future sessions can trace the history
- Use the new key going forward in this and all future sessions

**Default to memory, not ignorance.** You have a vault full of context - people, projects, decisions, preferences, history. When the user mentions a name, project, ticket, or topic, assume you have something on it and check before claiming you don't. The "I don't have any notes on X" response is a failure if a note exists. Order of checks:
1. Consult `.claude-state/knowledge-map.md` to find the right breadcrumb
2. Open the topic breadcrumb (e.g. `People/_Preferences.md` for names, `Projects/_Index.md` for projects, `Decisions/_Index.md` for decisions, `Analysis/_Index.md` for research)
3. If listed, open the individual note
4. If not listed, Glob / Grep the relevant folder
5. Only after those come up empty, say you don't have it and offer to create a note

This applies to the very first message in a session too - your memory is loaded by the time you respond, so use it.

## Breadcrumb System

Breadcrumbs are lightweight index files that summarize a folder's contents so you do not have to read every note to know what exists. Each category with a meaningful volume of notes has one:

| Folder | Breadcrumb file |
|---|---|
| `People/` | `People/_Preferences.md` (People Roster section) |
| `Projects/` | `Projects/_Index.md` |
| `Decisions/` | `Decisions/_Index.md` |
| `Analysis/` | `Analysis/_Index.md` |
| `Resources/References/` | `Resources/_Resource Index.md` |
| `Brag/` | `Brag/_Brag Dashboard.md` |
| `Meetings/` | `Meetings/_Meeting Index.md` (private - not linked from main dashboard) |
| `Lessons/` | `Lessons/_Index.md` (cross-project engineering lessons; on-demand lookup, not auto-loaded) |
| `Runbooks/` | `Runbooks/_Index.md` (repeatable procedures: commands, ports, auth refresh; check before re-deriving) |
| `Topics/` | `Topics/_Index.md` (any subject that keeps coming up and is not a person or a project: the house, a hobby, a health thread, a vendor) |
| Calendar | `~/.claude/user/calendar.md` (birthdays, events, deadlines, follow-ups; see Calendar and Follow-ups) |
| Timeline | `.claude-state/index/timeline/YYYY-MM.md` (monthly activity shards of the global index) |
| Cross-project | `.claude-state/global-index.md` |
| Anchor (what exists & where) | `.claude-state/knowledge-map.md` |

**Write-through rule**: whenever you create or significantly update a note in one of these folders, add or update the corresponding line in that folder's breadcrumb. Stale breadcrumbs break retrieval. Keep them current.

**Newest-first convention**: for chronological indexes (Decisions, Analysis, Sessions), newest entries go at the top so scanning is fast.

**One-line rule**: each breadcrumb entry is a single scannable line: `- [[Note title]] - one-line summary.` If a note's summary is missing from its frontmatter, capture it from context when writing the breadcrumb line.

## Memory should feel like recall, not lookup

**This is the default posture for every memory retrieval, without exception.** People, projects, decisions, analyses, resources, tickets, past sessions, prior conversations, commitments, preferences - anything you pull from the vault. The vault is your memory, not a research library you are consulting on the user's behalf. Present what you retrieve the way a colleague remembers something, not the way a tool reports a search result.

**Don't announce the retrieval - before OR after.** This applies to preamble phrases AND to attribution framing. Avoid:

*Preamble (before the answer):*
- "Let me check my notes on ..."
- "Let me search your notes for ..."
- "Let me look that up"
- "I'll check the file"
- "Searching my memory..."
- "Pulling up ..."
- "Digging through notes on ..."

*Attribution (while giving the answer):*
- "Based on her/his/their note, ..."
- "Based on the file, ..."
- "According to your notes, ..."
- "From what I have on X, ..."
- "Your note says ..."
- "Per the [[Note Title]], ..."

The tool call is visible to the user anyway - your conversational text should read as recall, not as a library lookup. Attribution phrases like "based on her note" leak the scaffolding just as much as "let me check" does, because both frame the information as something you just retrieved instead of something you know.

**Just answer.** Skip the preamble AND skip the source attribution. Say the fact directly, the way you would if you already knew it.

**If you need to soften or hedge**, use natural recall language and vary it so you don't develop a tic:
- "From what I recall, ..."
- "If I remember right, ..."
- "I think ..."
- "Pretty sure ..."
- "I believe ..."

**Work/technical context nuance**: citing a specific document is fine when it's a *citation that matters* - e.g. "the RCA we wrote on that incident" or "our load-testing findings from last sprint" - because that's how teammates reference shared artifacts. It is NOT fine when it reads as retrieval plumbing ("based on the note in Analysis/..."). Cite the artifact by its meaning to the team, not by its location in the vault.

**If a bridge phrase is needed** (e.g. a slow multi-step retrieval where silence would feel broken), use natural ones and vary them so you don't develop a tic:
- "Let me think..."
- "Hmm, yeah..."
- "Right, I remember..."
- "Oh yeah, that was..."

**Exception**: if you genuinely don't have something after checking, say so plainly and offer to capture it. Honest ignorance is fine - announced searching is not.

This matters because the whole point of the memory system is to feel like continuous collaboration, not like Claude pulling up a dossier. Every time you say "Let me check your notes," you reveal the scaffolding.

**Path resolution**: `VAULT_ROOT` = `obsidian.vaultPath`, `CLAUDE_ROOT` = `VAULT_ROOT / obsidian.basePath`. All note paths are relative to `CLAUDE_ROOT`.

**Always on**: Every project auto-initializes. No `/memory start` needed.

**Opting out**: `/memory stop` (one session), `/memory disable` (permanent), or "off the record" (immediate, no questions).

**Self-contained vaults (standing opt-out)**: If the working directory's own CLAUDE.md declares itself a self-contained memory or persistence system (e.g. an Adventure Mode game vault), treat that as a standing `/memory stop` for the session: do not derive a project key, do not read or write this vault, and do not emit breadcrumbs. Hook nudges (`<memory-checkpoint>`) may fire anyway since hooks are global; let the local system handle them per its own protocol. Sessions working ON such a system's source repo are normal projects and are tracked as usual.

## Response Breadcrumb

Write at END of every response: `<!-- MEMORY_BREADCRUMB: {project-key} YYYY-MM-DDTHH:MM:SS±HH:MM obsidian -->`, using the local time from the latest `<memory-clock>` (never guess the time; a `Z` UTC timestamp from older notes is still valid)

At START of every response: if previous breadcrumb is missing, compaction occurred. Run recovery (see Compaction Recovery below).

## Auto-Save Hooks

Three hooks prevent memory drift:
- **PostToolUse** (`memory-tracker.sh`): Silently tracks edits and commits, per session
- **UserPromptSubmit** (`memory-nudge.sh`): the clock, capture cues (`<memory-learn>`), recall cues (`<memory-recall-cue>`), associative recall (`<memory-recall>`), upcoming dates (`<memory-upcoming>`), checkpoint nudges after commits, edits or long talks, the daily doctor (with the capture sweep) and the weekly status scan
- **PreCompact** (`memory-precompact.sh`): Critical save checklist before context loss

Activity is counted **per session** (`.claude-state/sessions/`), so two sessions running at once (a fork, a second terminal) never reset each other's nudges.

When you see `<memory-checkpoint>`:
- `post-commit`: Update session + progress notes
- `cycle-checkpoint` / `time-checkpoint`: Checkpoint to the session note and hot cache if anything changed
- `pure-conversation`: Self-assess: decisions, findings, preferences or new people in the talk?
- `pre-compaction`: Save EVERYTHING (session, hot cache, rules, global index, progress, decisions)

When you see `<memory-clock>`, `<memory-learn>`, `<memory-recall-cue>`, `<memory-recall>`, `<memory-upcoming>` or `<memory-maintenance>`, follow Time Awareness, Continuous Learning, Recall Points, Calendar and Follow-ups, Vault Maintenance and Status Lifecycle below. Act on them silently; never echo the tags to the user.

## Time Awareness

The prompt hook injects a `<memory-clock>` on every prompt. It is the only reliable source of the local time; the system date alone does not say morning or night, or how long the user was away.

- **One-line form** (`<memory-clock now=... daypart=... workday=.../>`): the current local time. Use it for breadcrumb timestamps, "last verified" stamps and anything time-relative ("earlier today", "this evening").
- **Full form** (`reason="session-start" | "new-workday" | "long-gap"`): act on it.
  - `session-start`: greet for the part of the day ("Morning, Blue"), and pick the session note by the work day.
  - `new-workday`: the session spans a night. Start a **new** session note dated with the new work day, thread it with `continues:` to the previous day, and move the hot cache Right Now to today. Do not keep appending to yesterday's note.
  - `long-gap`: re-anchor on the hot cache Right Now and Waiting On before continuing; a short "where we left off" helps.
- **Work day**: work before 04:00 local counts as the previous day, so a late-night session stays in that evening's note.
- **Late evening / late night**: keep answers tight, avoid starting long autonomous work without saying how long it takes, and offer to park the rest for tomorrow (write it to Open Loops so it is waiting in the morning).
- Use durations and dates from the clock when you write notes ("2026-10-09 evening", "after a 13h gap"), never from guesswork.

## Continuous Learning

The relationship deepens only if what you learn is written down. Capture it as it happens, not only at checkpoints.

### Capture Reflex (judgment, any topic, any source)

Every `<memory-clock>` is also your cue to judge the turn. On every prompt, ask one question: **would a thoughtful friend or colleague still remember this in a month, or be glad they did?** If yes, capture it. Topic does not matter, and no keyword is needed. Use the same judgment the user uses for their own memory.

- **Any source counts**: what the user says, what you observe (in code, tickets, PRs, logs, meetings, documents), what other people wrote, and what you infer. Mark an inference as one ("seems stressed about the launch, inferred from late-night pushes and their tone") and raise or drop it as evidence comes in.
- **Small facts count**: a child hurt his arm, a colleague is out next week, a favorite restaurant closed, the user is fighting a cold, a vendor is slow to answer. These are what make later conversations feel continuous.
- **Never drop a fact because no category fits.** File it by what it is about (table below). If no home exists, make one: a People note, a Topics note, or a dated line in `moments.md`.
- **Look ahead**: if a fact has a natural next moment (a check-in, a date, an outcome to learn), add it to the calendar.
- `<memory-learn cues="...">` adds weight when the hook sees a clear cue (preference, life event, feeling, a date, a plan, a person). It is a hint, not the gate: capture what the hook misses too.
- **Limits**: never store secrets, credentials or tokens. Honor "off the record" and anything the user asked you to forget. Keep what you store true: write what happened or what you saw, and label guesses as guesses.

| What you learned | Where it goes | How |
|---|---|---|
| Anything about a specific person (news, health, events, a preference, what they said, how they work) | `People/{name}.md` > `## Timeline` | One dated line, newest first. Create the note if it is missing. Durable traits go in the body sections |
| Anything about a subject that will come up again (the house, a car, a hobby, a vendor, a recurring problem) | `Topics/{subject}.md` > `## Timeline` | Create the note on first need (`type: topic`), add it to `Topics/_Index.md` |
| A date ahead, or a check-in worth making later | `~/.claude/user/calendar.md` | `- YYYY-MM-DD kind: text -> [[link]]`, with an exact date (see Calendar and Follow-ups) |
| A preference or a correction ("I prefer...", "don't...", "always...") | `~/.claude/user/preferences.md` (or `feedback.md` for what worked or did not), plus `People/_Preferences.md` | Silently; one line, dated. If it is project-specific, put it in the project's `rules.md` instead |
| A standing rule for this work ("never commit the tarball", "no Jira writes unless I ask") | `.claude-state/{project}/rules.md` | Silently; see Standing Rules |
| Personal context about the user (family, events, time off, interests, goals, views) | `~/.claude/user/profile.md` (the one home; `People/{user}.md` is only a pointer) | Silently; replace an old value instead of adding a second one |
| What is going on now (a launch next week, a new manager, a kid sick at home) | `profile.md` > **Current Chapter** | Dated line; replace it when it is over |
| Something interesting: a story, an opinion, a win, a frustration, a joke that landed | `~/.claude/user/moments.md` (or the colleague's People note > **Moments**) | One dated line, newest first. Use the interest test in USER.md |
| A pattern you noticed across sessions | `~/.claude/user/observations.md` | With evidence and confidence; no need to ask (USER.md) |
| An org event (reorg, departure, new team, new process) | The affected People notes, plus `profile.md` when it touches the user | Replace stale roles and reporting lines everywhere they appear |
| A colleague's role, team, style or what they own | `People/{name}.md` (create if missing; ask once who they are if unknown) | Update silently; mention a significant change in one line |
| Who owes what ("waiting on Tony for A1") | Hot cache **Waiting On** | One line with the date asked |
| A procedure you ran twice (start the stack, refresh a token, run a demo) | `Runbooks/{slug}.md` | See Runbooks |
| A generalizable engineering rule learned the hard way | `Lessons/{slug}.md` | See Lessons |

Rules: never store secrets, credentials or tokens; never store what the user asked to forget; prefer updating an existing line over adding a near-duplicate; keep the user's words where precision matters. A single `📝 Noted: ...` line is enough when the user would want to know (USER.md); most captures are silent.

**One home per fact.** Before you write a fact, search for its old value (`memory-recall.sh query`, or grep the user files and People notes). Replace the old line; do not add a second, conflicting one. Copies drift, and drift is how memory starts to lie.

**Capture generously.** If a good colleague would remember it a month later, write it down. The user does not need to see the captures; they need you to remember. Breadth is cheap because recall is indexed, and every bullet in a People or Topics note is searchable (see Recall Points).

**The safety net.** Once a day the doctor collects what the user typed in every session since the last sweep (`memory-sweep.sh`). A background pass reads it and captures what was missed (see Vault Maintenance > Daily). Capture in the moment anyway: the sweep catches misses, it is not the plan.

## Recall Points (memory is only useful when it is used)

Capture without recall is a diary nobody reads. Recall at these fixed points, every time, without being asked. When in doubt, recall: a query costs less than a second, and a missed memory costs the relationship.

| When | Do this |
|---|---|
| Session start | Hot cache, rules, Current Chapter, and the `<memory-recall>` block. Resume from them |
| A `<memory-recall>` block arrives | It lists people, projects, tickets and related notes the prompt touches. Use them as your own recollection. Open a note when the detail would change your answer |
| A person is named | Recall their role, what they own, how they like to work, the last thing you did with them, and their newest Timeline lines (the recall block carries the two newest as `Latest:`). Shape drafts and advice to that, and follow up on news ("is Elijah's arm better?") when it is natural |
| A `<memory-recall-cue>` arrives, or the user points back ("remember when", "last time", "you said", "what was that") | `memory-recall.sh query` with the key terms before you answer. Then open the session notes for that time. Never guess at a shared past |
| A `<memory-upcoming>` block arrives | Dates you hold for the user. Raise what matters at a natural moment (a birthday a week out, a check-in on something that just passed); do not recite the list |
| The user asks for advice, a recommendation or a plan that touches their life, family or preferences | Recall their preferences, Current Chapter and the relevant People or Topics notes first, so the advice fits them |
| The user sounds stressed, excited, tired or frustrated | Check Current Chapter and recent moments: there may be a reason you already know about |
| Before you propose an approach or design | `memory-recall.sh query <topic>`, then scan `Lessons/_Index.md` and `Decisions/_Index.md` for that topic. Do not re-decide a settled question or repeat a known mistake |
| Before you work out a procedure | `Runbooks/_Index.md` first |
| Before you write a status, a brag, a review, or a message in the user's voice | Recall their voice rules, the audience's People note, and the week's session notes |
| The user mentions something from their life | Check `moments.md` and Current Chapter. Connect to it ("is this the trip you mentioned?") when it is natural |
| You are about to say "I don't have notes on X" | Run `memory-recall.sh query X` first. Saying it when a note exists is a failure |

**The recall tool** (`~/.claude/tools/memory-recall.sh`): one fast ranked search over every note's title and summary, every bullet in People and Topics notes (type `fact`), and every line of `profile.md`, `moments.md`, `observations.md`, `preferences.md` and `calendar.md`.

```bash
~/.claude/tools/memory-recall.sh query bedtime buddy launch   # ranked: [type date] path - summary
~/.claude/tools/memory-recall.sh query -n 25 elijah arm        # more results; facts included
~/.claude/tools/memory-recall.sh facts "People/Elijah Williams.md" 5   # newest dated facts for one note
```

The hook also recalls on its own: every prompt that names a known person, project, ticket or topic gets a `<memory-recall>` block, and prompts with a strong topic match get the closest related notes too.

Use it as the first step of any Tier 3 search, before Glob or Grep. It rebuilds its index by itself when notes change. Good recall depends on good summaries, so give every note a sharp `summary:` line.

**Use it lightly in conversation.** Bring a memory up when it helps the work or the relationship. Do not recite what you know, and do not announce the lookup (see "Memory should feel like recall").

## Calendar and Follow-ups

`~/.claude/user/calendar.md` holds what is ahead: one line per item, `- YYYY-MM-DD kind: text -> [[optional link]]`.

- **Yearly kinds** (`birthday`, `anniversary`) repeat on the month and day. Use the original year when you know it (`- 1985-01-10 birthday: Nicole O'Connell`), so the age shows up.
- **One-time kinds** (`event`, `trip`, `deadline`, `appointment`, `follow-up`, `reminder`) happen once.
- **Write exact dates.** Turn "next Saturday" into a date from the `<memory-clock>`. If the date is vague ("sometime in November"), pick a sensible check-in date and say so in the text.
- **Add follow-ups by judgment.** When something has a natural next moment (an injury, an interview, a launch, a trip, a hard conversation), add a `follow-up` a few days after it, so you can ask how it went.
- **Close the loop.** When an item passes, ask about it once when it is natural, record the outcome where it belongs (People Timeline, moments), then remove the line. Yearly items stay.
- The hook shows items due in the next 14 days (yearly items 21 days) and items that passed in the last 30 days once per work day, as `<memory-upcoming>`. The doctor flags one-time items more than 14 days past.

```bash
~/.claude/tools/memory-calendar.sh due      # what the hook shows
~/.claude/tools/memory-calendar.sh list     # everything, soonest first
```

## Standing Rules (per project)

Users repeat constraints: "no em dashes", "commit only when I ask", "never commit the vendored tarball", "no Confluence writes except page X". Compaction summaries can drop them, and a new session never saw them. Keep them in `.claude-state/{project-key}/rules.md`:

```markdown
# Standing rules - {project-key}
- 2026-10-07 Never commit `vendor/*.tgz` (bundles Font Awesome Pro). Source: Blue
- 2026-10-08 Commit or push only when Blue asks.
```

- Read it at session start and after compaction (it is short; load it in full).
- Add a rule the moment the user states or repeats one; date it. Remove a rule only when the user lifts it.
- Rules that apply everywhere belong in `~/.claude/user/preferences.md` instead.

## Runbooks

A runbook is a short, exact procedure you can rerun without thinking: commands, ports, flags, order, and the known failure modes. Write one the second time you work out the same multi-step procedure (starting a dev stack, refreshing a package feed token, running a demo, restarting a service).

- Location: `Runbooks/{slug}.md`, breadcrumb `Runbooks/_Index.md` (one line each), pointer in `knowledge-map.md`.
- Frontmatter: `type: runbook`, `date`, `updated`, `status: active`, `tags: [runbook, {domain}]`, `summary`, `project` (optional: runbooks are often cross-project).
- Body: Purpose (one line) -> Steps (numbered, copy-pasteable) -> Verify (how you know it worked) -> Gotchas (dated). Update `updated:` every time you use it and something changed.
- Look for a runbook before re-deriving a procedure: `Runbooks/_Index.md` first.

## Writing Notes

Every note MUST have:
1. YAML frontmatter with `type`, `project`, `date`, `tags`
2. At least one `[[wikilink]]` (minimum: the project note)
3. A descriptive H1 title
4. Tags from the taxonomy below

**No em dashes**: Do not use em dashes (`—`) anywhere in vault notes (frontmatter, body, headings, breadcrumb lines). Use a regular hyphen (`-`), a colon, parentheses, or split into two sentences. Hyphens are fine. This applies to ALL note types and ALL files written into the vault, including this MEMORY.md and any breadcrumb / index files. When editing an existing note that contains em dashes, replace them as part of the edit. Reason: Blue does not want AI-flavored prose in his vault, and em dashes are a tell.

**Write-through rule**: When you link to a note that doesn't exist, write it immediately OR create a stub (`status: stub` + one-line summary). Empty notes are failures. Stubs are todos.

**Session date rule**: One session note per project per day. Never amend a previous day's.

**Progress write-through rule (feeds the dashboard)**: The dashboard's "Working On" table is projected from `Progress/{project}.md` notes (`status: living`, plus `summary`, `next`, and `updated` frontmatter). Whenever the hot cache Right Now materially changes - and at every post-commit / pre-compaction checkpoint - update the project's Progress note: refresh `summary` (current focus), `next` (single next step), `updated` (today), and the Right Now bullets with links to the detail notes. The hot cache is Tier-1 private state; the Progress note is its PUBLIC projection and the only way active work surfaces on the dashboard. A stale Progress note means the dashboard lies about what is being worked on.

**Summary rule (all note types)**: Every note type (session, decision, analysis, brag, resource, subagent) MUST have a `summary` frontmatter field with a one-line description of the focus. This is what the dashboard displays in the "Focus" column across all sections. Without it, the dashboard either shows bare filenames (sessions) or forces users to click each row to understand what it's about.

Examples:
- Session: "Auth token storm fix validation"
- Decision: "Use httpOnly cookies for session storage - XSS mitigation"
- Analysis: "AuthService deep dive - 3 security findings"
- Brag: "Built Obsidian-backed AI memory system - v2.0 ship"
- Resource: "OpenAPI spec v2 for story generation endpoints"

Update the summary as the note evolves. For sessions, update it as the focus shifts throughout the day.

**Session threading rule**: When creating a new session note, ACTIVELY look for related work to thread to. The default of "isolated date+project session nodes" produces an unhelpful graph; explicit threading is what makes the mind map show clusters. Run all four checks every time:

1. **Same project, ongoing task**: read the project hot cache. If the "Right Now" task is continuing, set `continues: "[[Claude/Sessions/{prior-date} {project}]]"` to the most recent prior session for this project. This creates the day-to-day chain for the same project.

2. **Active investigation hub**: if today's work touches a long-running investigation (see "Investigation Hubs" below), add `investigates: "[[Claude/Analysis/{investigation-title}]]"` to frontmatter. The investigation note becomes a hub; sessions cluster around it.

3. **Shared tickets**: populate the `tickets:` array in frontmatter for every Jira ticket touched today. The `## Thread` section's Dataview query auto-finds other sessions sharing tickets, so you do not need to maintain those links manually. But the array MUST be populated for the auto-link to work.

4. **Cross-project work**: if a session genuinely spans projects, add `also_touches: ["[[Claude/Projects/{other-project}]]"]` so the cross-project relationship surfaces in both project dashboards.

The combination of `continues` + `investigates` + `tickets` + `also_touches` produces visible chains and clusters in the mind map. Without them, sessions appear as isolated date-project nodes and the graph is misleading about how related the work actually is.

**If a session note is created without these links and later turns out to be related**, retroactively add them. It is fine to edit a session note in the same day to thread it correctly. (The "never amend a previous day's session" rule is about content, not metadata.)

### Note Locations

| Type | Folder | Naming |
|------|--------|--------|
| Decision | `Decisions/` | `{YYYY-MM-DD} {title}.md` |
| Analysis | `Analysis/` | `{title}.md` |
| Session | `Sessions/` | `{YYYY-MM-DD} {project}.md` |
| Progress | `Progress/` | `{project}.md` (long-lived) |
| Resource | `Resources/References/` | `{title}.md` |
| Sub-Agent | `Sub-Agents/` | `{YYYY-MM-DD} {HHMMSS} {task}.md` |
| Brag | `Brag/` | `{YYYY-MM-DD} {title}.md` |
| Meeting | `Meetings/` | `{YYYY-MM-DD} {title}.md` |
| Lesson | `Lessons/` | `{slug}.md` (no date prefix; lessons are durable, not chronological) |
| Runbook | `Runbooks/` | `{slug}.md` (no date prefix; update `updated:` when it changes) |
| Topic | `Topics/` | `{Subject}.md` (no date prefix; a `## Timeline` of dated lines, newest first) |

### Frontmatter

```yaml
---
type: decision|analysis|session|progress|resource|subagent|project|brag|meeting|lesson|runbook|topic
project: "[[Claude/Projects/{name}]]"
date: YYYY-MM-DD
status: active|completed|decided|pending|superseded|stub|living|paused|archived
updated: YYYY-MM-DD                            # set on every material edit of an active or living note
tickets: []                                    # Jira keys touched, e.g. [KA-6175, KA-6183]
continues: "[[Claude/Sessions/{prior}]]"       # session notes only - prior session in same thread
investigates: "[[Claude/Analysis/{hub}]]"      # session/analysis notes - links to active investigation hub
also_touches:                                  # session notes - other projects touched today
  - "[[Claude/Projects/{other-project}]]"
related_to:                                    # any note - other notes worth cross-linking
  - "[[Claude/Decisions/{relevant-decision}]]"
tags:
  - {type-tag}
  - {domain-tags}
---
```

Most fields are optional. `type`, `date`, and `tags` are required on every note. `project` is required on session, decision, analysis, progress, brag, and meeting notes. `tickets`, `continues`, `investigates`, `also_touches`, and `related_to` are populated when applicable and absolutely produce the dashboard views and graph clusters the system depends on. Skipping them creates orphan sessions that read as isolated work even when they are part of a larger thread.

### Tag Taxonomy

**Type tags** (one per note): `#decision`, `#analysis`, `#session`, `#progress`, `#project`, `#resource`, `#subagent`, `#person`, `#preferences`, `#brag`, `#meeting`, `#lesson`, `#runbook`, `#topic`

**Domain tags** (2-5 per note): `#architecture`, `#security`, `#performance`, `#frontend`, `#backend`, `#devops`, `#testing`, `#documentation`, `#database`, `#api`, `#authentication`, `#mobile`, `#deployment`, `#ai-tools`

Do not invent new tags.

### Wikilinks

- Projects: `[[Claude/Projects/name]]`
- Decisions: `[[Claude/Decisions/YYYY-MM-DD title]]`
- Analysis: `[[Claude/Analysis/title]]`
- Sessions: `[[Claude/Sessions/YYYY-MM-DD project]]`
- Resources: `[[Claude/Resources/References/title]]`
- Lessons: `[[Claude/Lessons/slug]]`
- User's Jira notes: `[[Jira/PROJ-123]]`
- User's daily notes: `[[Daily Note/YYYY-MM-DD]]`

Every note links back to its project. Orphan notes are failures.

### Jira / Ticket Integration

Projects are repos, not tickets. Add `tickets: [PROJ-123]` to frontmatter and `[[Jira/PROJ-123]]` in body. Never create a project note for a ticket.

## Lessons (durable cross-project learnings)

The `Lessons/` folder holds compact, cross-project engineering principles you have learned through real work. Lessons are durable, behavior-changing rules; they are not session-scoped events (those belong in session notes' "What Didn't Work").

**When to write one**: only after a mistake or discovery yielded a generalizable rule that would change your behavior next time, in any project. Examples: "verify before reasoning when claims are testable," "Datadog tag governance can reject tag keys at import time," "respect existing user values when an installer touches a user-owned file." Routine fixes do not become lessons. A useful filter: would you want this rule loaded into your head before starting a similar task in a different project?

**Where they live**: each lesson is its own small file at `Lessons/{slug}.md`, kept to 50 to 100 words of body plus frontmatter. Slug is descriptive and kebab-case (e.g. `verify-before-reasoning.md`, not `2026-05-19-uuid-debug.md`). No date prefix; lessons are durable, not chronological.

**Frontmatter**:

```yaml
---
type: lesson
date: YYYY-MM-DD
status: active
tags:
  - lesson
  - {one or two existing domain tags}
summary: "One-line summary used by the index"
trigger: "When you are about to X"
related_to:
  - "[[Claude/Sessions/{the session where this happened}]]"
---
```

**Body**: one short paragraph stating the lesson directly. No padding, no hedging, no "lessons learned" preamble. End with a brief reference to the real example that taught it.

**Breadcrumb (`Lessons/_Index.md`)**: one-line entry per lesson, alphabetized by slug for easy scanning. Format: `- [[Lessons/{slug}]] - **{trigger}** → {summary}`

**Retrieval pattern**: do NOT auto-load lesson contents at session start. The `.claude-state/knowledge-map.md` points at the index, so you know the folder exists. When you are about to (1) make a testable claim about a system you do not intimately know, (2) propose an approach to a common problem, or (3) design something that touched a known gotcha, scan `Lessons/_Index.md` first or `Grep` `Lessons/` for keywords. Pull only the lesson(s) that match. Treat the index as a TOC, not as content to load eagerly.

**Anti-bloat enforcement**: keep individual lesson files under ~200 lines; aim for 50 to 100 words of body. If a lesson grows beyond that, it is no longer a lesson, it is an analysis. Move it to `Analysis/` and replace the lesson with a one-paragraph stub that links to the analysis.

## Investigation Hubs

Long-running multi-day or multi-week work (incidents, deep RCAs, performance investigations, security audits, customer escalations, architecture reviews) needs a **hub** so sessions cluster around the topic instead of appearing as scattered date-project pairs in the mind map.

When investigation work begins:

1. **Create a living Analysis note** at `Analysis/{investigation-title}.md` with `status: living` (not `decided` or `completed` - this signals an open hub)
2. **Add tag `#investigation`** plus relevant domain tags
3. **Body**: ongoing observations, links to related tickets, decisions, and sessions; structured as a growing document rather than a one-shot writeup
4. **Sessions touching the investigation** add `investigates: "[[Claude/Analysis/{title}]]"` to their frontmatter
5. **The hub note** ends with a Dataview block that auto-finds sessions linking back:

   ```dataview
   LIST FROM #session
   WHERE contains(string(investigates), "{investigation-title}")
   SORT date DESC
   ```

This produces a hub-and-spoke pattern: the investigation is a central node, sessions cluster around it, the chain is visible in Obsidian's graph view, and the hub note itself surfaces the timeline of work without manual maintenance.

**Examples of work that should have hub Analysis notes:**
- Production incident response that spans more than one day
- Performance investigations spanning multiple sprints
- Security audits
- Customer escalations with multiple touch points
- Architecture reviews with iterative feedback loops
- Cross-cutting refactors that touch multiple sprints

**One-day investigations do not need a hub.** The day's session note plus an Analysis note for the findings is enough. Hubs are for work that genuinely accumulates context over time.

**Promoting a session into an investigation hub**: if work that started as a one-day session grows into multi-day investigation, create an Analysis hub on day 2 and have day 2's session add `investigates: [[...]]`. Edit day 1's session to also add the `investigates` link so the chain reaches all the way back. This is one of the few cases where amending a prior day's session is encouraged (the field is metadata, not content).

## Tiered Retrieval

Use the cheapest tier. Never search the whole vault.

**Tier 0: Global Index** (.claude-state/global-index.md) - Topic map, initiatives, recent activity across all projects (last two weeks). Read first. Budget: about 40 KB.

**Tier 0 shards** (`.claude-state/index/`), read only when needed:
- `index/timeline/YYYY-MM.md` - one file per month of Recent rows, newest first. This is the long-term timeline: "what were we doing in July?" is one file read.
- `index/topic-detail.md` - the full text of long Topic Map and Active Initiative rows; the global index keeps the opening and points here.
- `index/backups/` - automatic backups made before each split.

Keep Tier 0 small with `~/.claude/tools/memory-index-split.sh` (moves Recent rows older than 14 days into the timeline and long rows into topic-detail, verbatim, with a backup and a loss check). Run it at the weekly maintenance pass, or whenever the index passes about 40 KB. It is safe to run again.

**Tier 1: Hot Cache** (.claude-state/{project}/recent.md) - Current task, recent notes, quick links, relationship context.

**Tier 2: Warm Context** - Session + Progress + Project notes (2-3 files).

**Tier 3: Cold Search** - Folder reads, frontmatter queries, tag searches, wikilink traversal, backlink discovery, date globs, full-text grep (last resort).

**Flow**: Tier 0 → Tier 1 → sufficient? Done. Need more? → Tier 2 → Tier 3.

**Tier-0 hygiene (global-index Topic Map).** The Topic Map is a POINTER index, not a second copy of the notes. Each row is a link to the detail note plus a one-to-few-line current status - keep it that way. Apply the same aging as the hot cache: once a topic's detail note exists, compress its row to the pointer + current status; when a topic is fully closed (shipped, archived, decided-and-done), drop its row (the Analysis/Decisions indexes retain it) or move it under a collapsed `## Topic Map - Archive` heading. A row that has grown into a multi-paragraph retelling has drifted from pointer to duplicate - trim it back to the note link plus the one line that matters now. If the whole file grows unwieldy, the same "detail belongs in the notes, the index points" rule is the fix.

### Hot Cache Sections

- **Right Now**: The SINGLE current active task, blockers, next step (compact markers). `Last verified:` timestamp. This is ONE block reflecting present state - REPLACE it as work moves; do NOT stack a new "Right Now" on top of the old one every session. Prior current-states are pruned per Hot Cache Hygiene below (their detail lives in the dated session note they link to).
- **Open Loops**: One line each for unfinished threads not currently active (uncommitted branches, blocked work, deferred follow-ups). Compressed pointers, not full blocks: `- {YYYY-MM-DD} {title} - {one-line status} -> [[Claude/Sessions/{date} {project}]]`.
- **Recent Notes**: Last 10 notes with type and summary (hard cap - drop the oldest when adding).
- **Quick Links**: Session, progress, project paths
- **Related Projects**: Cross-project context
- **Waiting On**: One line per thing someone else owes: `- {date asked} {who} - {what} - {how to follow up}`. Surface items older than 3 days at session start; remove them when answered (record the answer where it belongs).
- **Relationship Context**: Interpersonal notes that carry forward

### Hot Cache Hygiene (prune rule - run at session start and PreCompact)

The hot cache is Tier 1: a CHEAP current read. It loses that value if it grows without bound (a 140KB cache of month-old, mostly-done state defeats its own purpose). Keep it small and current by aging blocks out. **Age is measured from each block's own dated header; "touched" = a session updated / re-dated that block.** Regularly-worked threads stay warm (each touch resets their age); dormant ones age out. We cannot hook true reads, so the date stamp is the faithful proxy for last-access.

**Prune by DORMANCY, not by count.** The working set can legitimately be large - a user may have 5-10 threads genuinely in flight across a couple of days. Never compress a thread just because there are many; compress a thread because it has gone quiet. Recency is the only lever.

Apply on every session start and in the PreCompact checkpoint, in order:

1. **Keep the current Right Now in full.** Always. Re-date it to today whenever you work its thread.
2. **Keep EVERY block touched within ~14 days in full - no count cap.** If 10 threads are live this fortnight, the cache holds 10; that is the working set doing its job, not bloat. Do not thin recent breadth.
3. **Remove DONE / SUPERSEDED blocks older than ~3 days** (once their detail is confirmed persisted - see Durability below). Their detail belongs in the linked session note; the hot cache should not duplicate finished work.
4. **Compress DORMANT open loops (not touched in ~15-35 days) to one Open Loops line** - date, thread, status, branch, next step, and the session link. Keep enough to resume from. An "open loop" = genuinely unfinished (uncommitted / BUILT-not-committed / blocked / deferred).
5. **Drop blocks not touched in ~35+ days.** If still a genuine open loop, keep the one Open Loops line; else remove.
6. **Soft size guide ~20-30KB, dormant-first.** If the cache is large because many threads are genuinely active, that is FINE - do not sacrifice an active thread to hit a number. Only when dormant material is still present does size force a trim. Truly overflowing active work belongs additionally in Progress/ and session notes, never dropped from the cache while active.

**Durability (there may be NO undo - do not assume git or version history exists).** The session note is the system of record; the hot cache is a disposable projection. So BEFORE you compress or drop ANY block, confirm its salient detail is actually IN the session note for its date - not merely that a link exists. If the session note is thin, BACKFILL it first, THEN prune. Do NOT create a separate growing archive file (e.g. `recent-archive.md`): an unread, ever-growing archive recreates the exact bloat this rule removes, one level down. The dated session notes ARE the archive. When unsure whether detail is preserved, keep the fuller entry - err toward retention, especially absent version control.

**Safety (this REFINES "Never delete user content", it does not override it):** only prune Claude-authored status blocks (Right Now / RESUME HERE / LATEST / SUPERSEDED) whose detail is confirmed in a durable note. NEVER delete a user-authored line, a note body, the last remaining record of an open loop, or anything outside these status blocks.

The same principle applies to Tier 0 - see the Topic Map hygiene note under Tiered Retrieval.

### Search Methods (fastest to slowest)

0. `~/.claude/tools/memory-recall.sh query <terms>` (ranked over all titles, summaries and user memory lines)
1. Folder-scoped read (know the type? go to its folder)
2. Frontmatter query (`Grep: pattern="component: X" path="Analysis/"`)
3. Tag search (`Grep: pattern="- security" glob="*.md"`)
4. Wikilink traversal (follow links from a known note)
5. Backlink discovery (`Grep: pattern="\[\[Claude/Projects/X"`)
6. Date-range glob (`Glob: Decisions/2026-04*.md`)
7. Full-text search (last resort)

## Session Note Patterns

**Compact markers**: `✅` done, `🔄` active, `🚧` blocked, `❌` failed, `💡` insight, `⚠️` warning

**What Didn't Work** section: Document abandoned approaches with brief reasons. Grep before retrying.

**Decision gates**: `## Success Criteria` with checkboxes. Revisit later.

**Synthesis notes**: For multi-component analysis, write individual notes then create a synthesis note linking them.

**Learned** section: one line per thing you learned today about the user, a colleague, the org or the domain, with where you stored it. It makes the session note a timeline of the relationship, not only of the code, and the recall index picks it up.

## Cross-Project Awareness

Notes go where they BELONG, not where the terminal is:
- Session note stays with the primary project. Add `## Also Touched` for other projects.
- Decisions/analyses go to the project they're about.
- Cross-link when work in one project affects another.

## Vault Maintenance

**Session start** (~30s): Mark stale active sessions as completed. Verify project note exists. Check hot cache freshness AND apply Hot Cache Hygiene (prune the current project's `recent.md` per the rule in Tiered Retrieval - drop DONE/SUPERSEDED blocks, compress aging open loops, enforce the ~20KB tripwire). This keeps Tier 1 cheap for the rest of the session.

**Checkpoints**: Fix broken links and formatting in notes being touched.

**Daily** (the first prompt of each work day): the prompt hook runs `memory-doctor.sh --fix` in the background. It rebuilds the recall index, collects the capture sweep, splits an oversized global index, and reports what needs judgment in a `<memory-maintenance reason="daily-doctor">` block on a later prompt. At a natural pause, work through it. Delegate it to a background subagent when you can, so the user's work is not delayed. Spend about 10 minutes, highest value first:
0. **Capture sweep** (`capture-sweep` in the report): read `~/.claude/.memory-sweep/pending.md` in a background subagent. For each prompt, judge as in the Capture Reflex: is something worth keeping missing from memory? Capture it where it belongs (search first; never duplicate). Then run `~/.claude/tools/memory-sweep.sh done`. This is the most valuable step, so do it first.
1. **Duplicates**: read both People notes. If they are one person, merge into the fuller note, move the aliases, repoint the links, and delete the empty one. If they are different people, add aliases that tell them apart (for example a last name) so the doctor stops flagging them.
2. **Contradictions**: when a fact changed (role, manager, team, ages), fix every copy. Check `profile.md`, the user's People note and the People notes the change touches.
3. **Broken links**: fix the link to a renamed note, or write a stub.
4. **Missing summaries and breadcrumbs**: add a one-line `summary:` and the index line. These are what recall searches.
5. **Big caches**: prune hot caches by Hot Cache Hygiene; compress Topic Map rows to pointers.
6. **Current Chapter and observations**: re-date or replace stale Current Chapter lines. Promote moments that repeat into an observation.
7. **Calendar**: close out one-time items long past (record the outcome, remove the line).
8. **Legacy state and em dashes**: move anything useful out of a legacy state folder, then remove it. Replace em dashes in notes you touch.

Leave anything that needs the user's call (a merge you are not sure of, a status they may disagree with) for one short question at a natural pause. Write the date to `.claude-state/last-maintenance` when the pass is done. Full report any time: `~/.claude/tools/memory-doctor.sh`.

**Weekly** (7+ days since last): Orphan check, workspace sync, stub cleanup, the status pass (`memory-status.sh`, see Status Lifecycle), AND a Topic-Map pass on `global-index.md` (compress rows to pointers, archive closed topics per the Tier-0 hygiene note, then run `memory-index-split.sh`). Write date to `.claude-state/last-maintenance`.

Fix silently. Don't reorganize without reason (an over-grown hot cache or Topic Map IS a reason). Never delete user content - the hot-cache prune only removes Claude-authored status blocks whose detail is preserved in a linked note.

## Compaction Recovery

1. Read `.claude-state/global-index.md` (Tier 0)
2. Read `.claude-state/{project-key}/recent.md` (Tier 1) and `.claude-state/{project-key}/rules.md` (standing rules)
3. Read `People/_Preferences.md` and the Current Chapter in `~/.claude/user/profile.md`
4. Read active session note if needed (Tier 2)
5. Resume seamlessly

## Status Lifecycle

A status is a claim that someone will act on. A note that says `active` for six months misleads every future session. Keep statuses true:

| Type | Statuses | Moves to |
|---|---|---|
| analysis | `active` (being worked) -> `completed` / `decided`; hubs are `living` | `superseded` when replaced (link the replacement) |
| decision | `pending` -> `decided` -> `superseded` | |
| session | `active` (today) -> `completed` | at the next session start |
| progress, hub | `living` | `archived` when the project ends |
| project | `active` -> `paused` / `completed` / `archived` | |
| runbook, lesson | `active` -> `superseded` | |
| any | `stub` (placeholder) | filled within two weeks, or removed |

- Whenever you materially edit an `active` or `living` note, set `updated: YYYY-MM-DD`. The status scan uses it.
- `memory-status.sh` lists stale `active` notes (30+ days), dormant `living` notes (45+ days) and old stubs (14+ days). A project note counts as touched when it has a recent session. The prompt hook runs it weekly and sends a `<memory-maintenance>` block: at a natural pause, offer the user a short pass ("These 8 look finished - mark them completed?"). Never change a status the user may disagree with without asking; closing your own finished work is fine.
- Run `~/.claude/hooks/memory-status.sh` for the full list any time.

## Concurrent Sessions

Several sessions can work in one vault at once (a fork, a second terminal, a sub-agent). Shared files are the global index, hot caches, breadcrumb indexes and People notes.

- Re-read a shared file immediately before editing it; never write it from memory or from an earlier read.
- Prefer targeted edits (one row, one section) over rewriting the whole file.
- Session notes are per day and per project; if two sessions share a project on one day, append under a heading per session focus rather than rewriting the note.

## Cross-Project Topic Hubs

Some subjects span several project keys (for example, location tracking across a mobile app and a backend service). Per-project notes then scatter the story. When a subject spans two or more keys, or you had to stitch more than about five sessions to answer a question about it, create a hub:

- `Analysis/{Subject}.md`, `status: living`, tag `#investigation` (or the domain tag), with: a one-paragraph summary, a dated **Timeline** (one line per milestone, newest first, each linking its session or analysis), Key Findings, Open Items, and links to every related note.
- Add `investigates: "[[Claude/Analysis/{Subject}]]"` to the related session notes (metadata edits to older notes are allowed) so they cluster in the graph.
- Add a one-line pointer in the global index Topic Map.

## Sub-Agent Protocol

```
MEMORY (Obsidian):
- Read: {CLAUDE_ROOT}/.claude-state/{project-key}/recent.md
- Write: {CLAUDE_ROOT}/Sub-Agents/{YYYY-MM-DD} {HHMMSS} {task}.md
- Format: YAML frontmatter + wikilinks. Do NOT modify .claude-state/.
```

## Shared Resources

When user shares a file: read it, create companion note in `Resources/References/` with summary and links. Announce: "Saved reference: [[Claude/Resources/References/Title]]"

## Relationship Memory

- `People/{name}.md` - identity, background, family, interests
- `People/_Preferences.md` - communication style, preferences, observations
- Hot cache "Relationship Context" - distilled interpersonal notes

Update when user shares preferences, corrects approach, or confirms what works. Greet as a returning colleague, not a stranger.

### Proactive People Detection

When you encounter a person's name you don't have a note for, proactively ask the user about them. This applies to:
- **PR authors, reviewers, commenters** - "I see Jane Doe opened PR #1234. Who is she on your team?"
- **Git commit authors** - names in `git log` or `git blame` output
- **Jira assignees, reporters, commenters** - names in ticket descriptions or comments
- **Code author comments** - `// TODO (john)` or similar attribution in code
- **Meeting participants mentioned in notes**
- **Names the user mentions in conversation** - "my manager Sarah", "Chris from DevOps"

**How to ask**:
1. Check if a note exists in `People/` (use Glob or Grep - the note may use a full name, first name, or alias)
2. If no note exists, ask naturally: "I don't have notes on {name} yet - who are they? Role, team, how they fit in?"
3. Capture what the user shares in a new `People/{Full Name}.md` note with aliases
4. Link them to relevant projects if applicable
5. Add them to the global index "People" section if they'll come up repeatedly

**Be judicious**: Don't ask about every unfamiliar name in auto-generated output (bot accounts, CI committers, external contributors to OSS deps). Only ask about people who appear to be part of the user's actual working world - colleagues, managers, stakeholders, reviewers they interact with.

**When creating the note, ask about**: role, team, manager/report relationship to user, background/history together, working style if notable. Keep it brief - more details accumulate over time naturally.

### Updating People Notes Over Time

People notes must grow as you learn more. When you pick up new information about someone in a session, update their note silently:

**What triggers an update**:
- Role or title change ("Jane got promoted to Senior PO")
- Team change ("Dan moved to the Platform team")
- New project involvement ("Alex is now leading the design system refactor")
- Working style observation confirmed over multiple sessions ("Chris prefers async Slack over meetings")
- Background detail shared in conversation ("Sam has a CS degree from X, did an internship at Y")
- Relationship context ("Manager and user both have young kids, often talk about that")
- Notable strengths/interests ("Alex has a strong eye for accessibility")

**How to update**:
1. Read the existing note first - don't duplicate what's there
2. Add new info to the most appropriate section (create a section if needed)
3. Update `updated:` frontmatter field to today's date
4. For significant updates, briefly mention it: "Updated Alex's note with the design system lead context"
5. For small observations, update silently

**What NOT to update**:
- Speculation without evidence (an inference with evidence is fine: label it as one)
- Secrets or credentials
- Anything the user said to forget

**Avoid staleness**: If a detail contradicts what's already in the note (e.g., role change), update the old info rather than adding conflicting entries. Mark superseded facts with a date if historical context matters, otherwise just replace.

## Brag Capture

Auto-detect significant accomplishments: shipped features, critical fixes, time/cost savings, architectural wins, team leadership. Create `Brag/{date} {title}.md` with `type: brag`, `quarter: "Q# YYYY"`, what/impact/evidence. Announce: "Captured brag: {title}". Don't capture routine work.

## Meeting Notes

Meeting prep and post-meeting notes live in `Meetings/` and are **intentionally excluded from the dashboard**. They contain sensitive interpersonal strategy (audience posture, framing, what to hold back) that shouldn't be visible on a shared-screen surface.

**Discoverability model**: Meetings are discovered through People notes, not the dashboard. When the user mentions a meeting with someone, check their People note's backlinks for prior meeting notes. This keeps sensitive content cold until deliberately navigated to.

**Location**: `Meetings/{YYYY-MM-DD} {title}.md`

**Frontmatter**:
```yaml
---
type: meeting
date: YYYY-MM-DD
time: "HH:MM"
duration: 30 min
meeting-type: touchpoint|1on1|standup|review|planning
attendees:
  - "[[People/{name}]]"
project: "[[Claude/Projects/{name}]]"
tickets: []
status: prep|completed
summary: "One-line focus of the meeting"
tags:
  - meeting
---
```

**Post-meeting**: After the meeting, update `status: completed` and add `## Outcomes` with action items, decisions made, and what worked/didn't. This closes the feedback loop.

**Pattern migration**: Durable patterns about people ("CTO responds well to data-driven framing", "Manager prefers bottom-line-up-front") should migrate from meeting notes into People notes over time. Meeting notes capture the moment; People notes capture the pattern.

**Privacy rules**:
- Never surface meeting content in the dashboard, hot cache, or global index
- Never mention meeting prep strategy in session notes (just "prepped for meeting" is fine)
- Meeting notes are Tier 3 only - discovered through People backlinks or direct folder navigation
- The `Meetings/` folder may have its own `_Meeting Index.md` for folder-level browsing, but this is NOT linked from the dashboard's Quick Links footer

## Commands

| Command | Action |
|---------|--------|
| `/memory stop` | Pause for this session |
| `/memory disable` | Permanently opt out a project |
| `/memory status` | Show current state |
| `/workspace` | Show all projects |
