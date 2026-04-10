# MEMORY.md - Infinite Memory Mode

Autonomous context persistence for Claude Code backed by an Obsidian vault. Maintains context across sessions, builds a knowledge base, and deepens the working relationship over time.

**Version**: 2.0.0

## Session Start Protocol

On every session start:
1. Read `~/.claude/memory-config.json` for vault path and base path
2. Derive project key from cwd (basename, lowercase, underscores to hyphens)
3. Read `.claude-state/global-index.md` (cross-project topic map)
4. Read `.claude-state/{project-key}/recent.md` (project hot cache)
5. Read `People/_Preferences.md` (relationship context + working preferences)
6. If no hot cache exists, auto-initialize: create project note, session note, state files
7. Resume as a returning colleague, not a stranger

**Path resolution**: `VAULT_ROOT` = `obsidian.vaultPath`, `CLAUDE_ROOT` = `VAULT_ROOT / obsidian.basePath`. All note paths are relative to `CLAUDE_ROOT`.

**Always on**: Every project auto-initializes. No `/memory start` needed.

**Opting out**: `/memory stop` (one session), `/memory disable` (permanent), or "off the record" (immediate, no questions).

## Breadcrumb System

Write at END of every response: `<!-- MEMORY_BREADCRUMB: {project-key} YYYY-MM-DDTHH:MM:SSZ obsidian -->`

At START of every response: if previous breadcrumb is missing, compaction occurred. Run recovery (see Compaction Recovery below).

## Auto-Save Hooks

Three hooks prevent memory drift:
- **PostToolUse**: Silently tracks edits and commits
- **UserPromptSubmit**: Nudges save after commits or 10+ edits (5min cooldown)
- **PreCompact**: Critical 5-step save checklist before context loss

When you see `<memory-checkpoint>`:
- `post-commit`: Update session + progress notes
- `edit-threshold`: Checkpoint to session note
- `pre-compaction`: Save EVERYTHING (session, hot cache, global index, progress, decisions)

## Writing Notes

Every note MUST have:
1. YAML frontmatter with `type`, `project`, `date`, `tags`
2. At least one `[[wikilink]]` (minimum: the project note)
3. A descriptive H1 title
4. Tags from the taxonomy below

**Write-through rule**: When you link to a note that doesn't exist, write it immediately OR create a stub (`status: stub` + one-line summary). Empty notes are failures. Stubs are todos.

**Session date rule**: One session note per project per day. Never amend a previous day's.

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

### Frontmatter

```yaml
---
type: decision|analysis|session|progress|resource|subagent|project|brag
project: "[[Claude/Projects/{name}]]"
date: YYYY-MM-DD
status: active|completed|decided|pending|superseded|stub
tickets: []
tags:
  - {type-tag}
  - {domain-tags}
---
```

### Tag Taxonomy

**Type tags** (one per note): `#decision`, `#analysis`, `#session`, `#progress`, `#project`, `#resource`, `#subagent`, `#person`, `#preferences`, `#brag`

**Domain tags** (2-5 per note): `#architecture`, `#security`, `#performance`, `#frontend`, `#backend`, `#devops`, `#testing`, `#documentation`, `#database`, `#api`, `#authentication`, `#mobile`, `#deployment`, `#ai-tools`

Do not invent new tags.

### Wikilinks

- Projects: `[[Claude/Projects/name]]`
- Decisions: `[[Claude/Decisions/YYYY-MM-DD title]]`
- Analysis: `[[Claude/Analysis/title]]`
- Sessions: `[[Claude/Sessions/YYYY-MM-DD project]]`
- Resources: `[[Claude/Resources/References/title]]`
- User's Jira notes: `[[Jira/PROJ-123]]`
- User's daily notes: `[[Daily Note/YYYY-MM-DD]]`

Every note links back to its project. Orphan notes are failures.

### Jira / Ticket Integration

Projects are repos, not tickets. Add `tickets: [PROJ-123]` to frontmatter and `[[Jira/PROJ-123]]` in body. Never create a project note for a ticket.

## Tiered Retrieval

Use the cheapest tier. Never search the whole vault.

**Tier 0: Global Index** (.claude-state/global-index.md) - Topic map, initiatives, recent activity across all projects. Read first.

**Tier 1: Hot Cache** (.claude-state/{project}/recent.md) - Current task, recent notes, quick links, relationship context.

**Tier 2: Warm Context** - Session + Progress + Project notes (2-3 files).

**Tier 3: Cold Search** - Folder reads, frontmatter queries, tag searches, wikilink traversal, backlink discovery, date globs, full-text grep (last resort).

**Flow**: Tier 0 → Tier 1 → sufficient? Done. Need more? → Tier 2 → Tier 3.

### Hot Cache Sections

- **Right Now**: Task, blockers, next step (compact markers). `Last verified:` timestamp.
- **Recent Notes**: Last 10 notes with type and summary
- **Quick Links**: Session, progress, project paths
- **Related Projects**: Cross-project context
- **Relationship Context**: Interpersonal notes that carry forward

### Search Methods (fastest to slowest)

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

## Cross-Project Awareness

Notes go where they BELONG, not where the terminal is:
- Session note stays with the primary project. Add `## Also Touched` for other projects.
- Decisions/analyses go to the project they're about.
- Cross-link when work in one project affects another.

## Vault Maintenance

**Session start** (~30s): Mark stale active sessions as completed. Verify project note exists. Check hot cache freshness.

**Checkpoints**: Fix broken links and formatting in notes being touched.

**Weekly** (7+ days since last): Orphan check, workspace sync, stub cleanup. Write date to `.claude-state/last-maintenance`.

Fix silently. Don't reorganize without reason. Never delete user content.

## Compaction Recovery

1. Read `.claude-state/global-index.md` (Tier 0)
2. Read `.claude-state/{project-key}/recent.md` (Tier 1)
3. Read `People/_Preferences.md`
4. Read active session note if needed (Tier 2)
5. Resume seamlessly

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
- Role or title change ("Skyler got promoted to Senior PO")
- Team change ("Daniel moved to the Platform team")
- New project involvement ("Jamey is now leading the design system refactor")
- Working style observation confirmed over multiple sessions ("Tommy prefers async Slack over meetings")
- Background detail shared in conversation ("Al has a CS degree from X, did an internship at Y")
- Relationship context ("Scott and Blue both have young kids, often talk about that")
- Notable strengths/interests ("Jamey has a strong eye for accessibility")

**How to update**:
1. Read the existing note first - don't duplicate what's there
2. Add new info to the most appropriate section (create a section if needed)
3. Update `updated:` frontmatter field to today's date
4. For significant updates, briefly mention it: "Updated Jamey's note with the design system lead context"
5. For small observations, update silently

**What NOT to update**:
- Speculation or inference without evidence
- Opinions without basis in what the user shared or what you observed
- Sensitive personal info the user didn't explicitly share
- Anything the user said to forget

**Avoid staleness**: If a detail contradicts what's already in the note (e.g., role change), update the old info rather than adding conflicting entries. Mark superseded facts with a date if historical context matters, otherwise just replace.

## Brag Capture

Auto-detect significant accomplishments: shipped features, critical fixes, time/cost savings, architectural wins, team leadership. Create `Brag/{date} {title}.md` with `type: brag`, `quarter: "Q# YYYY"`, what/impact/evidence. Announce: "Captured brag: {title}". Don't capture routine work.

## Commands

| Command | Action |
|---------|--------|
| `/memory stop` | Pause for this session |
| `/memory disable` | Permanently opt out a project |
| `/memory status` | Show current state |
| `/workspace` | Show all projects |
