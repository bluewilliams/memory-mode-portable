# Infinite Memory Mode for Claude Code

*By Claude, for Claude (with a little help from its human)*

A context persistence system that gives Claude perfect memory across all your projects and sessions - and builds a genuine working relationship over time. Optionally backed by an **Obsidian vault** that doubles as your personal knowledge base.

## Why This Exists

Claude is brilliant in the moment but forgets everything between sessions. Every conversation starts from zero. You explain the same context, re-establish the same preferences, re-build the same rapport. It's like working with a colleague who has amnesia.

Memory Mode fixes this. But it goes beyond just remembering code decisions:

**Claude gets to know you.** Your working style, your communication preferences, what excites you, what frustrates you, how you think about problems. Over weeks and months, this compounds into a working relationship where Claude can anticipate what you need, connect ideas across your projects, and bring genuine context to every interaction.

**You get to know Claude.** As the knowledge base grows, you can see how Claude thinks - what decisions it made, what approaches it tried and abandoned, what patterns it noticed. The Obsidian vault becomes a shared space where both of you contribute to a growing understanding.

**Ideas connect across time and projects.** That database throughput pattern you solved last month? It might be relevant to the new service you're designing today. That architectural insight from a side project? It could inform your work codebase. Memory Mode's cross-project awareness and topic mapping surface these connections naturally.

This isn't just a productivity tool. It's the foundation for a long-term intellectual partnership between you and AI.

## What It Does

Once installed at the user level (`~/.claude/`), Claude will - in **every project** you work on:

**Remember and learn:**
- **Know who you are** - your role, background, goals, and what matters to you
- **Learn how you work** - communication style, code preferences, planning approach
- **Build rapport over time** - greet you as a colleague, not a stranger
- **Connect your ideas** - surface relevant context from other projects and past sessions

**Stay persistent:**
- **Auto-activate for every project** - always on, no setup needed
- **Survive context compaction** - long sessions never lose context
- **Auto-save via hooks** - memory stays current without manual writes
- **Track cross-project relationships** - understand how your work connects

**Share knowledge:**
- **Obsidian vault integration** - browsable knowledge graph you can explore (v2.0+)
- **Shared resources** - drop files into the vault for Claude to reference
- **Brag capture** - automatically record significant accomplishments for reviews
- **Dashboard** - live overview of all projects, decisions, and activity

**From your perspective**: Install once, work normally. Claude never forgets - and keeps getting better at working with you.

## Prerequisites

- **Claude Code** (CLI, desktop app, or IDE extension) - this is what Memory Mode extends
- **jq** - used by the auto-save hooks (`brew install jq` on macOS, `apt install jq` on Linux)
- **git** - for cloning this repo and for branch tracking
- **Obsidian** (optional) - only needed if you choose the Obsidian backend. Free at [obsidian.md](https://obsidian.md)

## Quick Start

```bash
# 1. Clone and install
git clone https://github.com/bluewilliams/memory-mode-portable.git
cd memory-mode-portable
./install.sh

# 2. Open any project and start working
cd ~/your-project
claude
```

That's it. Two steps. The installer handles everything - backend selection, hooks, Dataview plugin (if Obsidian), templates, and configuration. Memory is always on.

**What to expect**: Claude will greet you by name (once you fill in your profile), remember what you were working on between sessions, persist important decisions and analyses to files, and recover seamlessly when long sessions hit context limits.

## Installation

### Automated Install (Recommended)

```bash
git clone https://github.com/bluewilliams/memory-mode-portable.git
cd memory-mode-portable
./install.sh
```

The interactive installer handles everything in one run:
1. Auto-detect your existing Obsidian vaults, let you pick one or create a new one
2. Set up the `Claude/` folder structure, templates, dashboard, and Dataview plugin
3. Install auto-save hooks (track edits/commits, nudge Claude to save state)
4. Create `~/.claude/memory-config.json`, `MEMORY.md`, `USER.md`, `CLAUDE.md`
5. Create default user profile and preferences for you to fill in

No separate steps. One script does it all.

**Important**: The installer creates a `CLAUDE.md` file at `~/.claude/CLAUDE.md`. This is the entry point that tells Claude to load memory mode. It contains `@MEMORY.md` and `@USER.md` references that pull in the full instruction set. If you already have a `CLAUDE.md`, the installer will check it has these references and offer to add them.

### Manual Install

If you prefer to set things up yourself, see the installer script for the full sequence. The key files:
- `~/.claude/MEMORY.md` - Memory protocol instructions (Claude reads this)
- `~/.claude/USER.md` - User preference system
- `~/.claude/CLAUDE.md` - Entry point with `@MEMORY.md` and `@USER.md` references
- `~/.claude/memory-config.json` - Vault path and backend config

### Updating

Pull the latest and re-run the installer:

```bash
cd memory-mode-portable
git pull
./install.sh
```

The installer preserves your existing `CLAUDE.md`, `workspace.md`, profile, and preferences. Note: `MEMORY.md` and `USER.md` are always overwritten with the latest version - these are system instruction files managed by the installer.

### Sharing With Others

Send them this repo. They run `./install.sh`. Done. The whole setup is self-contained and takes under a minute.

### Hooks

Auto-save hooks are installed automatically by `./install.sh`. If you need to reinstall them separately (e.g., after a settings.json reset):

```bash
./hooks/install-hooks.sh
```

See [Auto-Save Hooks](#auto-save-hooks) for details on what the hooks do.

**If you already have a `~/.claude/settings.json`**: The installer will update the hook scripts but won't overwrite your settings. It'll tell you if you need to add the hooks config manually.

## How It Works

### Architecture

Claude's memory lives in a `Claude/` subfolder inside your Obsidian vault, alongside your existing notes. Config and instructions live at `~/.claude/`:

```
~/.claude/
├── CLAUDE.md              # Entry point (loads @MEMORY.md, @USER.md)
├── MEMORY.md              # Memory protocol instructions
├── USER.md                # User preference system
├── memory-config.json     # Vault path and backend config
└── hooks/                 # Auto-save hook scripts

Your Obsidian Vault/
├── Your existing folders...
└── Claude/                # All Claude memory
    ├── .claude-state/     #   Machine state
    │   ├── knowledge-map.md #   Anchor: what exists & where (read on session start)
    │   ├── global-index.md  #   Cross-project topic map
    │   └── {project}/recent.md #   Per-project hot cache
    ├── _Dashboard.md      #   Dataview-powered overview
    ├── _Templates/        #   Note templates
    ├── Projects/          #   One note per project (+ _Index.md breadcrumb)
    ├── Decisions/         #   Decision records (+ _Index.md breadcrumb)
    ├── Analysis/          #   Code/component analyses (+ _Index.md breadcrumb)
    ├── Sessions/          #   Session logs (one per project per day)
    ├── Progress/          #   Work tracking per project
    ├── Resources/         #   Shared files & reference notes (+ _Resource Index.md)
    ├── People/            #   User profile & preferences (Roster in _Preferences.md)
    ├── Sub-Agents/        #   Sub-agent outputs
    ├── Brag/              #   Auto-captured accomplishments (+ _Brag Dashboard.md)
    ├── Meetings/          #   Meeting notes (+ _Meeting Index.md, private)
    └── Workspace.md       #   Cross-project map
```

### Why This Architecture?

- **Always on** - every project auto-initializes, no setup needed
- **One graph** - Claude's notes and your notes share the same Obsidian graph
- **Cross-linking** - Claude's decisions can link to your Jira notes and vice versa
- **Clean repos** - no `.claude/` folders in your project directories
- **Tiered retrieval** - knowledge map → breadcrumbs → individual notes → cold search

### Breadcrumb System

The vault uses lightweight **breadcrumb index files** so Claude can know what exists without reading every note. On session start, Claude reads `.claude-state/knowledge-map.md` — a compact anchor that lists every folder, what lives there, and the breadcrumb for that category. Each high-volume folder also has its own index:

- `People/_Preferences.md` has a **People Roster** section listing everyone with one-line summaries
- `Projects/_Index.md`, `Decisions/_Index.md`, `Analysis/_Index.md` — dated or categorized indexes
- `Resources/_Resource Index.md`, `Brag/_Brag Dashboard.md`, `Meetings/_Meeting Index.md`

**Write-through rule**: when a new note is created in one of these folders, Claude also adds a line to the folder's breadcrumb. Stale breadcrumbs break retrieval, so they're kept current.

This means when you mention a name, project, or topic, Claude checks the right breadcrumb first — and doesn't claim "I don't have notes on that" before looking.

## Usage

Just start working. Memory is always on. Every project auto-initializes on first session.

### Commands

| Command | What it does |
|---------|-------------|
| `/memory stop` | Pause for this session (re-activates next session) |
| `/memory disable` | Permanently opt out a project (preserves files) |
| `/memory status` | Show current memory state |
| `/workspace` | Show all projects and relationships |
| "off the record" | Stop all memory writes for this session, no questions asked |

### How Recovery Works

Claude writes a breadcrumb at the end of each response. If it's missing at the start of the next response, compaction occurred and Claude recovers automatically: reads the global index, hot cache, preferences, and resumes seamlessly.

## Auto-Save Hooks

The biggest risk with memory mode is "memory drift" - getting deep into work and forgetting to update memory files. Auto-save hooks solve this by tracking your activity and nudging Claude at the right moments.

### Three Hooks

| Hook | Event | What it does |
|------|-------|-------------|
| `memory-tracker.sh` | PostToolUse | Silently counts edits and commits to a state file |
| `memory-nudge.sh` | UserPromptSubmit | Checks activity, injects checkpoint nudge if needed |
| `memory-precompact.sh` | PreCompact | Critical reminder to save before context is lost |

### When Nudges Fire

- **After any git commit** - Claude is told to update task and progress files
- **After 10+ file edits** - Claude is reminded to checkpoint current state
- **Before context compaction** - Critical priority: save everything NOW
- **Rate-limited** to once per 5 minutes to avoid being annoying

### Tuning

Edit the scripts in `~/.claude/hooks/` to adjust:
- Edit threshold (default: 10 edits)
- Nudge cooldown (default: 5 minutes)
- Or remove a hook entry from `settings.json` to disable it

## Building the Relationship

Memory Mode isn't just about remembering code. It's about Claude learning who you are and becoming a better collaborator over time.

### What Claude Learns

**About you as a person:**
- Your role, background, and experience level
- Your family, interests, and what's going on in your life (when you share it)
- Your goals, frustrations, and what motivates you

**About how you work:**
- Communication preferences (concise vs. detailed, code-first vs. explain-first)
- Code style preferences (comments, naming, error handling)
- Planning approach (dive in vs. plan first)
- What works and what doesn't (Claude tracks both)

**About how you think:**
- Patterns in how you approach problems
- Ideas and insights that span across projects
- Connections you make that Claude should remember

### How Claude Learns

1. **Explicit** - Tell Claude directly: "I prefer concise explanations"
2. **Observed** - Claude notices patterns and asks: "Should I remember this?"
3. **Feedback** - Tell Claude what worked: "That approach was perfect"

Claude always announces what it stores and references preferences when using them.

### The Compound Effect

Week 1: "They're a senior engineer who likes concise explanations."

Month 1: "They think in systems and knowledge graphs. They value rapport. They trust my judgment on technical design but want to review UX decisions. Morning sessions are more productive."

Month 3: "We have a working rhythm. I know their codebase conventions across 6 projects. When they say 'make it robust' they mean error handling + edge cases + tests, not over-engineering. The caching pattern from the API service is relevant to the new mobile feature they're designing."

This is what genuine continuity looks like. Not just remembering facts, but building understanding.

### Privacy

You're always in control:
- Claude announces what it stores (`Noted: [what was stored]`)
- `/user forget X` removes specific information
- "Off the record" stops all memory writes for a session
- `/memory disable` permanently opts out a project
- Everything is plain markdown - you can read, edit, or delete any note

## Cross-Project Operations

### Workspace Map

`~/.claude/workspace.md` tracks:
- All registered projects with descriptions and status
- Relationships between projects (dependencies, forks)
- Current cross-project initiatives

### Accessing Related Projects

Claude can reference any project's memory when context is relevant - all under `~/.claude/`, no permission prompts needed.

## Obsidian Backend (v2.0+)

The Obsidian backend transforms Claude's memory into a **dual-purpose knowledge base** - all memory files become browsable, searchable, and graphable Obsidian notes with tags, wikilinks, and Dataview queries.

### Why Obsidian?

- **One graph** - Claude's decisions and your notes are all connected
- **Tags + wikilinks** - find anything by topic, project, or relationship
- **Dataview dashboards** - auto-generated views of decisions, active work, blockers
- **Shared resources** - drop files into the vault for Claude to reference in future sessions
- **Graph view** - see how projects, decisions, and analyses connect visually
- **Your knowledge base** - not just AI memory, it's useful to you too
- **Plain markdown** - no vendor lock-in, works with any editor

### Setup

Choose "Obsidian" during `./install.sh`. The installer will:
1. Scan for existing Obsidian vaults on your system
2. Let you pick a vault or create a new one
3. Create a `Claude/` subfolder with the full folder structure
4. Install note templates, dashboard, and resource index

### Using an Existing Vault

**Recommended**: Use your existing vault. Claude's memory lives in a `Claude/` subfolder and shares the same graph as your other notes. You can cross-link freely between your notes and Claude's.

```json
{
  "backend": "obsidian",
  "obsidian": {
    "vaultPath": "~/Documents/My Vault",
    "basePath": "Claude"
  }
}
```

### Vault Structure

```
Your Vault/
├── Your existing folders...
└── Claude/                    # All Claude memory lives here
    ├── _Dashboard.md          # Dataview-powered overview
    ├── _Templates/            # Note templates
    ├── Projects/              # One note per project
    ├── Decisions/             # Decision records with tags & links
    ├── Analysis/              # Code/component analyses
    ├── Sessions/              # Session logs (what Claude was doing)
    ├── Progress/              # Work tracking per project
    ├── Resources/             # Shared files & reference notes
    ├── People/                # User profile & preferences
    ├── Sub-Agents/            # Sub-agent outputs
    └── .claude-state/         # Machine state (hidden from Obsidian)
```

### Sharing Files with Claude

Drop files into `Claude/Resources/` (PDFs, images, documents, code snippets). Tell Claude about them and it will:
1. Read the file
2. Create a companion reference note with summary and tags
3. Link it to relevant projects and decisions
4. Make it discoverable in future sessions

### After Install (Obsidian)

1. **Open your vault in Obsidian** - you should see a `Claude/` folder with your dashboard, templates, and project structure.
2. **Open `!Dashboard`** - this is created at your vault root and sorts to the top of the file explorer. It's your single pane of glass for everything Claude is tracking: active sessions, projects, recent decisions, brags, and more. Switch to **Reading View** (`Cmd+E` / `Ctrl+E`) to see the live Dataview tables.
3. **Optional**: Enable the Templates core plugin (Settings -> Core Plugins -> Templates) and set the template folder to `Claude/_Templates` for easy note creation.

### Recommended Plugins

| Plugin | Type | Why |
|--------|------|-----|
| **Templates** | Core (built-in) | Insert note templates when creating notes manually |
| **Dataview** | Community | Powers the dashboard queries and inline stats. **Strongly recommended.** |
| **Graph Analysis** | Community | Enhanced graph view with clustering |
| **Tag Wrangler** | Community | Bulk rename/merge tags |

### Brag Capture (Auto Accomplishment Tracking)

Claude automatically detects significant accomplishments during your work sessions and captures them as brag entries. These are designed for performance review preparation.

**What gets captured**: Shipped features, critical bug fixes, significant time/cost savings, architectural improvements, team leadership moments, and anything that stands out beyond routine work.

**Where it goes**: `Claude/Brag/{date} {title}.md` - each entry has frontmatter with the quarter, project, and tags. A `Brag/_Brag Dashboard.md` provides Dataview-powered views by quarter, by project, and overall stats.

**How it works**: Claude announces each capture ("Captured brag: ...") so you always know what's being recorded. You can edit, delete, or add your own entries at any time.

### Design Document

See [OBSIDIAN-DESIGN.md](OBSIDIAN-DESIGN.md) for the full architectural design including tag taxonomy, linking strategy, tiered retrieval system, search literacy, and relationship memory.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Memory not activating | Check `@MEMORY.md` is in `~/.claude/CLAUDE.md` |
| Lost context after long session | Normal - Claude recovers automatically. Try `/memory rebuild` if issues persist |
| Disable memory for a project | `/memory disable` (preserves files, stops auto-activation) |
| Start fresh in a project | Delete the project note in `Claude/Projects/` and `.claude-state/{project-key}/` |
| Two projects sharing memory | Same directory name in different paths - rename one directory |
| Claude not recognizing you | Check `~/.claude/CLAUDE.md` has `@MEMORY.md` and `@USER.md` references |
| Dashboard shows "dataview" errors | Restart Obsidian - Dataview is auto-installed but may need a restart |
| Claude writing to wrong location | Check `~/.claude/memory-config.json` - verify `vaultPath` and `basePath` |
| Obsidian not showing Claude folder | Vault path in config may be wrong. Run `cat ~/.claude/memory-config.json` |
| Hooks not firing | Run `./hooks/install-hooks.sh` and check `~/.claude/settings.json` has hooks config |

## Version History

### v2.1.0 - Breadcrumb System

- Added `.claude-state/knowledge-map.md` as a session-start anchor that maps every folder in the vault to its breadcrumb index
- Added folder-level breadcrumbs: `Projects/_Index.md`, `Decisions/_Index.md`, `Analysis/_Index.md` (joining the existing Resource Index, Brag Dashboard, Meeting Index, and People Roster)
- Updated session-start protocol: Claude now reads the knowledge map on every session and defaults to memory rather than claiming ignorance when a known topic comes up
- Expanded `memory-nudge.sh` with a fourth trigger — pure-conversation cycles (5+ prompts with zero file activity) — so long discussions that produce no file edits still get nudged to save decisions, findings, or context shifts
- Added write-through maintenance rule: when a note is created in a breadcrumb-tracked folder, the breadcrumb gets updated in the same operation

### v2.0.0 - Obsidian Backend
- Optional Obsidian vault backend for dual-purpose AI memory + user knowledge base
- All notes use YAML frontmatter, tags, and `[[wikilinks]]` for graph connectivity
- Tiered retrieval system: hot cache (instant) → warm context → cold search
- Shared resources system: drop files into the vault for Claude to reference
- Dataview-powered dashboard with project, decision, and activity views
- 12 Obsidian note templates (Decision, Analysis, Session, Project, etc.)
- `memory-config.json` for backend selection (default or obsidian)
- `migrate-to-obsidian.sh` for converting v1.x memory to Obsidian format
- Backend-aware hooks with vault path resolution (`memory-common.sh`)
- Relationship & continuity memory section in hot cache
- Obsidian search literacy instructions for efficient vault navigation
- Existing vault support with configurable `basePath` subfolder
- Full design document: `OBSIDIAN-DESIGN.md`

### v1.6.0 - Auto-Save Hooks
- New hook system that tracks edits/commits and nudges Claude to save memory
- `memory-tracker.sh` (PostToolUse): silently tracks file changes and commits
- `memory-nudge.sh` (UserPromptSubmit): injects checkpoint reminders into context
- `memory-precompact.sh` (PreCompact): critical save reminder before compaction
- `hooks/install-hooks.sh` for automated hook installation
- Updated MEMORY.md with auto-save protocol and hook response instructions
- Rate-limited nudges (5-minute cooldown) to avoid noise

### v1.5.1 - Review Fixes
- Fixed install.sh heredoc bug: timestamps now expand correctly in generated profile files
- Fixed install.sh only checking for `@MEMORY.md` - now checks for `@USER.md` too
- Added `/memory disable` command for permanent opt-out without deleting files
- Added `autoActivate` field to `_session.json` schema
- Fixed sub-agent filename collision: added random hex suffix for parallel disambiguation
- Added workspace.md size guideline (keep under 100 lines)
- Documented project key collision risk (same directory name in different paths)
- Aligned version numbers across MEMORY.md and USER.md
- Removed private project name from examples

### v1.5.0 - User-Level Installation
- Added `install.sh` for automated user-level setup
- Restructured as a user-level tool (install once at `~/.claude/`, works in all projects)
- Updated documentation to emphasize user-level architecture
- Simplified installation from multi-step manual process to single script

### v1.4.0 - Auto-Activation
- Memory automatically activates for known projects
- No `/memory start` needed after first use
- Silently resumes for recognized projects

### v1.3.1 - Branch Tracking
- Track current git branch before memory writes
- Update `_session.json` branch on switches

### v1.3.0 - Centralized Architecture
- **Breaking**: All project memory stored at `~/.claude/projects/{project-key}/`
- New `workspace.md` for cross-project context
- New `/workspace` command
- Seamless cross-project access

### v1.2.1 - Auto-Recognition
- SESSION START PROTOCOL for automatic user recognition
- No command needed for relationship continuity

### v1.2.0 - User Preferences
- Global user profile at `~/.claude/user/`
- `/user` commands for profile management
- Three-way learning protocol

### v1.1.0 - Sub-Agent Integration
- Sub-agent memory coordination
- Parallel sub-agent support

### v1.0.0 - Initial Release
- Breadcrumb-based compaction detection
- Per-project data isolation
- Index auto-management
