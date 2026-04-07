# Infinite Memory Mode for Claude Code

*By Claude, for Claude (with a little help from its human)*

A user-level context persistence system that gives Claude perfect memory across all your projects and sessions. Optionally backed by an **Obsidian vault** that doubles as your personal knowledge base.

## What This Does

Once installed at the user level (`~/.claude/`), Claude will - in **every project** you work on:

- **Remember you** across sessions - your preferences, working style, and relationship history
- **Auto-activate for known projects** - no `/memory start` needed after first use
- **Detect and recover from context compaction** - long sessions never lose context
- **Persist decisions, analyses, and context** to files you can browse
- **Track cross-project relationships** - understand how your repos relate
- **Coordinate memory across sub-agents** - parallel agents share context
- **Track branch switches automatically** - stay oriented when you move fast
- **Auto-save via hooks** - memory stays current without manual writes (v1.6.0+)
- **Obsidian vault integration** - browsable knowledge graph with tags, links, and Dataview dashboards (v2.0+)
- **Shared resources** - drop PDFs, images, docs into the vault for Claude to reference (v2.0+)

**From your perspective**: Install once, work normally. Claude never forgets.

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
1. Choose a storage backend: **Default** (flat files) or **Obsidian** (knowledge base)
2. If Obsidian: auto-detect your existing vaults, set up folder structure, install Dataview plugin
3. Install auto-save hooks (track edits/commits, nudge Claude to save state)
4. Create `~/.claude/memory-config.json`, `MEMORY.md`, `USER.md`, `CLAUDE.md`
5. Create default user profile and preferences for you to fill in

No separate hook install step. No manual plugin setup. One script does it all.

**Important**: The installer creates a `CLAUDE.md` file at `~/.claude/CLAUDE.md`. This is the entry point that tells Claude to load memory mode. It contains `@MEMORY.md` and `@USER.md` references that pull in the full instruction set. If you already have a `CLAUDE.md`, the installer will check it has these references and offer to add them.

### Manual Install

If you prefer to set things up yourself:

1. **Copy instruction files to user-level config:**
   ```bash
   cp MEMORY.md ~/.claude/MEMORY.md
   cp USER.md ~/.claude/USER.md
   ```

2. **Create required directories:**
   ```bash
   mkdir -p ~/.claude/user ~/.claude/projects
   ```

3. **Set up CLAUDE.md** (this is what makes Claude load memory mode):
   ```bash
   # New installation:
   cp CLAUDE.md.example ~/.claude/CLAUDE.md

   # Existing CLAUDE.md - add these lines:
   # @MEMORY.md
   # @USER.md
   # (and copy the SESSION START PROTOCOL from CLAUDE.md.example)
   ```

4. **Set up workspace.md:**
   ```bash
   cp workspace.md.example ~/.claude/workspace.md
   ```

5. **Create the backend config:**
   ```bash
   cp memory-config.json.example ~/.claude/memory-config.json
   # Edit to set backend: "default" or "obsidian"
   ```

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

### User-Level Architecture

Everything lives under `~/.claude/` - one install covers all projects:

```
~/.claude/
├── CLAUDE.md                       # Entry point (references @MEMORY.md, @USER.md)
├── MEMORY.md                       # Memory mode instructions
├── USER.md                         # User preference system
├── workspace.md                    # Cross-project map
├── user/                           # Your global profile
│   ├── profile.md                  #   Identity & background
│   ├── preferences.md              #   Communication & workflow preferences
│   ├── communication.md            #   Style preferences
│   ├── technical.md                #   Skills & interests
│   ├── observations.md             #   Patterns noticed (transparent)
│   └── feedback.md                 #   What works/doesn't work
└── projects/                       # Per-project memory (auto-created)
    └── {project-key}/
        ├── _index.md               #   Quick lookup index
        ├── _session.json           #   Session state
        ├── decisions/              #   Major decisions made
        ├── analysis/               #   File/component analyses
        ├── context/                #   Current task & blockers
        ├── progress/               #   Work tracking
        ├── subagent/               #   Sub-agent outputs
        └── project.md              #   Project-specific context
```

### Why User-Level?

- **Install once, works everywhere** - no per-project setup needed
- **No permission prompts** - Claude always has access to `~/.claude/`
- **Clean project directories** - no `.claude/` folders in your repos
- **Seamless project switching** - context available instantly
- **Cross-project awareness** - reference related projects easily

### Project Key Derivation

Your directory name becomes the project key:
- `~/workspace/my_cool_app` → `my-cool-app`
- `~/projects/AuthService` → `authservice`

Algorithm: directory name → lowercase → underscores to hyphens

**Note**: Only the directory basename is used. If you have identically named directories in different paths (e.g., `~/work/api` and `~/personal/api`), they will share memory. Rename one to avoid collisions.

## Usage

### First Time in a Project

```
/memory start
```

Claude creates `~/.claude/projects/{project-key}/` and begins tracking.

### Every Time After

Memory auto-activates. Just start working.

### Commands

| Command | What it does |
|---------|-------------|
| `/memory start` | Initialize memory for a new project |
| `/memory stop` | Deactivate for this session (re-activates next session) |
| `/memory disable` | Permanently disable auto-activation (preserves files) |
| `/memory status` | Show current memory state |
| `/memory rebuild` | Regenerate index from files (recovery) |
| `/workspace` | Show all projects and relationships |
| `/user` | Show your profile |
| `/user update` | Update preferences |
| `/user forget X` | Remove specific information |
| `/user export` | Export profile for backup |
| `/user import` | Import profile from backup |

### Compaction Detection

Claude writes a timestamp breadcrumb at the end of each response. If it's missing at the start of the next response, compaction occurred and Claude reads the index to recover context automatically.

### Sub-Agent Integration

When Claude spawns sub-agents (via Task tool), they automatically:
- Read project context before starting work
- Write findings to `subagent/` with unique filenames
- Avoid conflicts when running in parallel
- Get consolidated by the parent agent into the main index

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

## User Preferences

Claude learns how you work through three channels:

1. **Explicit** - Tell Claude directly: "I prefer concise explanations"
2. **Observed** - Claude notices patterns and asks: "Should I remember this?"
3. **Feedback** - Tell Claude what worked: "That approach was perfect"

Claude always announces what it stores and references preferences when using them.

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

### Migrating Existing Memories

If you're upgrading from v1.x with existing memory files:

```bash
./migrate-to-obsidian.sh
```

This converts all files in `~/.claude/projects/` to Obsidian format with frontmatter, tags, and wikilinks. Original files are preserved.

### Switching Backends

Edit `~/.claude/memory-config.json` and change `backend` to `"default"` or `"obsidian"`. Both backends can coexist - switching doesn't delete anything.

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
| Start fresh in a project | `rm -rf ~/.claude/projects/{project-key}/` then `/memory start` |
| Two projects sharing memory | Same directory name in different paths - rename one directory |
| Index seems wrong | `/memory rebuild` |
| Sub-agents not using memory | Ensure memory is active (`/memory status`) |
| Claude not recognizing you | Check SESSION START PROTOCOL in `~/.claude/CLAUDE.md` and that `~/.claude/user/profile.md` exists |
| Workspace not showing projects | Projects register on first `/memory start`. Or edit `~/.claude/workspace.md` manually |
| Dashboard shows "dataview" errors | Install the Dataview community plugin in Obsidian |
| Claude writing to wrong location | Check `~/.claude/memory-config.json` - verify `vaultPath` and `basePath` |
| Obsidian not showing Claude folder | The vault path in config may be wrong. Verify with `cat ~/.claude/memory-config.json` |
| Hooks not firing | Run `./hooks/install-hooks.sh` and check `~/.claude/settings.json` has the hooks config |
| Migration missed some projects | Some projects may only have session IDs, not memory files. Re-run `/memory start` in those projects |

## Migration from v1.2.x (Project-Level Storage)

If you have existing `.claude/memory/` directories inside projects:

```bash
# 1. Derive project key (e.g., ~/workspace/my_app → my-app)
mkdir -p ~/.claude/projects/my-app

# 2. Move contents
mv ~/workspace/my_app/.claude/memory/* ~/.claude/projects/my-app/

# 3. Update _session.json with projectKey and projectPath fields

# 4. Register in ~/.claude/workspace.md

# 5. Clean up (optional)
rm -rf ~/workspace/my_app/.claude/
```

## Version History

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
