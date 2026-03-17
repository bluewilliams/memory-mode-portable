# Infinite Memory Mode for Claude Code

A user-level context persistence system that gives Claude perfect memory across all your projects and sessions.

## What This Does

Once installed at the user level (`~/.claude/`), Claude will — in **every project** you work on:

- **Remember you** across sessions — your preferences, working style, and relationship history
- **Auto-activate for known projects** — no `/memory start` needed after first use
- **Detect and recover from context compaction** — long sessions never lose context
- **Persist decisions, analyses, and context** to files you can browse
- **Track cross-project relationships** — understand how your repos relate
- **Coordinate memory across sub-agents** — parallel agents share context
- **Track branch switches automatically** — stay oriented when you move fast

**From your perspective**: Install once, work normally. Claude never forgets.

## Installation

### Automated Install (Recommended)

```bash
git clone https://github.com/bluewilliams/memory-mode-portable.git
cd memory-mode-portable
./install.sh
```

The installer will:
- Create `~/.claude/user/` and `~/.claude/projects/` directories
- Copy `MEMORY.md` and `USER.md` to `~/.claude/`
- Set up `CLAUDE.md` with the Session Start Protocol (or guide you to update yours)
- Create `workspace.md` from template
- Create default user profile and preferences

### Manual Install

1. **Copy instruction files to user-level config:**
   ```bash
   cp MEMORY.md ~/.claude/MEMORY.md
   cp USER.md ~/.claude/USER.md
   ```

2. **Create required directories:**
   ```bash
   mkdir -p ~/.claude/user ~/.claude/projects
   ```

3. **Set up CLAUDE.md:**
   ```bash
   # New installation:
   cp CLAUDE.md.example ~/.claude/CLAUDE.md

   # Existing CLAUDE.md — add these lines:
   # @MEMORY.md
   # @USER.md
   # (and copy the SESSION START PROTOCOL from CLAUDE.md.example)
   ```

4. **Set up workspace.md:**
   ```bash
   cp workspace.md.example ~/.claude/workspace.md
   ```

### Updating

Pull the latest and re-run the installer:

```bash
cd memory-mode-portable
git pull
./install.sh
```

The installer preserves your existing `CLAUDE.md`, `workspace.md`, profile, and preferences. Note: `MEMORY.md` and `USER.md` are always overwritten with the latest version — these are system instruction files managed by the installer.

### Sharing With Others

Send them this repo. They run `./install.sh`. Done.

## How It Works

### User-Level Architecture

Everything lives under `~/.claude/` — one install covers all projects:

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

- **Install once, works everywhere** — no per-project setup needed
- **No permission prompts** — Claude always has access to `~/.claude/`
- **Clean project directories** — no `.claude/` folders in your repos
- **Seamless project switching** — context available instantly
- **Cross-project awareness** — reference related projects easily

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

## User Preferences

Claude learns how you work through three channels:

1. **Explicit** — Tell Claude directly: "I prefer concise explanations"
2. **Observed** — Claude notices patterns and asks: "Should I remember this?"
3. **Feedback** — Tell Claude what worked: "That approach was perfect"

Claude always announces what it stores and references preferences when using them.

## Cross-Project Operations

### Workspace Map

`~/.claude/workspace.md` tracks:
- All registered projects with descriptions and status
- Relationships between projects (dependencies, forks)
- Current cross-project initiatives

### Accessing Related Projects

Claude can reference any project's memory when context is relevant — all under `~/.claude/`, no permission prompts needed.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Memory not activating | Check `@MEMORY.md` is in `~/.claude/CLAUDE.md` |
| Lost context after long session | Normal — Claude recovers automatically. Try `/memory rebuild` if issues persist |
| Disable memory for a project | `/memory disable` (preserves files, stops auto-activation) |
| Start fresh in a project | `rm -rf ~/.claude/projects/{project-key}/` then `/memory start` |
| Two projects sharing memory | Same directory name in different paths — rename one directory |
| Index seems wrong | `/memory rebuild` |
| Sub-agents not using memory | Ensure memory is active (`/memory status`) |
| Claude not recognizing you | Check SESSION START PROTOCOL in `~/.claude/CLAUDE.md` and that `~/.claude/user/profile.md` exists |
| Workspace not showing projects | Projects register on first `/memory start`. Or edit `~/.claude/workspace.md` manually |

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

### v1.5.1 - Review Fixes
- Fixed install.sh heredoc bug: timestamps now expand correctly in generated profile files
- Fixed install.sh only checking for `@MEMORY.md` — now checks for `@USER.md` too
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
