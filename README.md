# Infinite Memory Mode for Claude Code

Autonomous context persistence system that allows Claude to maintain perfect memory across arbitrarily long sessions.

## What This Does

When enabled, Claude will:
- Automatically detect when context compaction occurs
- Persist important decisions, analyses, and context to files
- Recover seamlessly when context is lost
- **Store all project memory centrally** for seamless cross-project access (v1.3.0+)
- **Coordinate memory across sub-agents** (v1.1.0+)
- **Remember your preferences across all projects** (v1.2.0+)
- **Recognize you automatically in every new session** (v1.2.1+)
- **Track cross-project relationships and initiatives** (v1.3.0+)

**From your perspective**: Work normally. Claude never forgets - and always knows who you are.

## Installation

### Quick Install (Copy-Paste)

1. **Copy config files to your global Claude config:**
   ```bash
   cp /path/to/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   cp /path/to/memory-mode-portable/USER.md ~/.claude/USER.md
   ```

2. **Create the required directories:**
   ```bash
   mkdir -p ~/.claude/user ~/.claude/projects
   ```

3. **Set up CLAUDE.md (for auto-recognition):**
   ```bash
   # If you don't have a CLAUDE.md yet, use our example:
   cp /path/to/memory-mode-portable/CLAUDE.md.example ~/.claude/CLAUDE.md

   # Or add these lines to your existing CLAUDE.md:
   # (Copy the SESSION START PROTOCOL from CLAUDE.md.example, then add:)
   # @MEMORY.md
   # @USER.md
   ```

4. **Set up workspace.md (for cross-project context):**
   ```bash
   # Use our example as a starting point:
   cp /path/to/memory-mode-portable/workspace.md.example ~/.claude/workspace.md

   # Then edit it to add your projects
   ```

5. **Done!** Claude will now recognize you in every session. Use `/memory start` for project-specific memory.

### Fresh Claude Installation

If you're setting up Claude Code from scratch:

1. **Create the global config directories:**
   ```bash
   mkdir -p ~/.claude/user ~/.claude/projects
   ```

2. **Copy the config files:**
   ```bash
   cp /path/to/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   cp /path/to/memory-mode-portable/USER.md ~/.claude/USER.md
   cp /path/to/memory-mode-portable/workspace.md.example ~/.claude/workspace.md
   ```

3. **Set up CLAUDE.md:**
   ```bash
   # Recommended: Use our example config (includes auto-recognition)
   cp /path/to/memory-mode-portable/CLAUDE.md.example ~/.claude/CLAUDE.md

   # Or if you have existing config, add the session protocol and references
   # (see CLAUDE.md.example for the SESSION START PROTOCOL to copy)
   ```

### Sharing With a Friend

Send them:
1. This `memory-mode-portable/` folder (includes `MEMORY.md`, `USER.md`, `workspace.md.example`, and this `README.md`)
2. Tell them to follow the "Fresh Claude Installation" steps above

## Usage

### Starting Memory Mode
In any project, tell Claude:
```
/memory start
```
or
```
Start infinite memory mode
```

Claude will:
- Create `~/.claude/projects/{project-key}/` for centralized storage
- Initialize session tracking
- Register the project in `~/.claude/workspace.md`
- Begin autonomous memory management

### Stopping Memory Mode
```
/memory stop
```

Files are preserved. You can restart anytime.

### Checking Status
```
/memory status
```

Shows active/inactive state, file counts, and session info.

### Viewing Workspace
```
/workspace
```

Shows all registered projects, their relationships, and current initiatives.

### Rebuilding Index (Recovery)
```
/memory rebuild
```

If the index gets out of sync, this regenerates it from actual files.

## How It Works

### Centralized Storage (v1.3.0+)

All memory is stored centrally under `~/.claude/`:
```
~/.claude/
├── CLAUDE.md                       # Entry point (references @MEMORY.md, @USER.md)
├── MEMORY.md                       # Memory mode instructions
├── USER.md                         # User preference instructions
├── workspace.md                    # Cross-project map (v1.3.0+)
├── user/                           # Global user profile
│   ├── profile.md
│   ├── preferences.md
│   ├── communication.md
│   ├── technical.md
│   ├── observations.md
│   └── feedback.md
└── projects/                       # All project memories (v1.3.0+)
    └── {project-key}/              # One directory per project
        ├── _index.md               # Quick lookup index
        ├── _index-archive.md       # Archived old entries
        ├── _session.json           # Session state
        ├── decisions/              # Major decisions made
        ├── analysis/               # File/component analyses
        ├── context/                # Current task & blockers
        ├── progress/               # Work tracking
        ├── subagent/               # Sub-agent outputs
        └── project.md              # Project-specific context
```

### Why Centralized?

- **No permission prompts**: Claude always has access to `~/.claude/`
- **Seamless project switching**: Context available for any project instantly
- **Cross-project awareness**: Easy to reference related projects
- **Clean project directories**: No `.claude/` folders in your repos

### Project Key Derivation

The project key comes from your directory name:
- `~/workspace/my_cool_app` → `my-cool-app`
- `~/projects/AuthService` → `authservice`

Algorithm: directory name → lowercase → underscores to hyphens

### Global User Profile

Your preferences follow you across all projects:
```
~/.claude/user/
├── profile.md          # Identity & background
├── preferences.md      # Communication & workflow preferences
├── communication.md    # Style preferences
├── technical.md        # Skills & interests
├── observations.md     # Patterns noticed (transparent)
└── feedback.md         # What works/doesn't work
```

### Workspace Map (v1.3.0+)

Track relationships between projects:
```
~/.claude/workspace.md
├── Repository Registry     # All known projects
├── Repository Relationships # How projects relate
└── Current Initiatives     # Cross-project work in progress
```

### Compaction Detection
Claude writes a timestamp "breadcrumb" at the end of each response. If that breadcrumb is missing at the start of the next response, Claude knows compaction occurred and reads the index to recover context.

### Index Management
- Index keeps only the 20 most recent entries (stays small)
- Older entries are archived automatically
- Individual files contain full details
- `/memory rebuild` can recover from any drift

## Sub-Agent Integration (v1.1.0+)

When Claude spawns sub-agents via the Task tool, they can participate in the memory system:

### How It Works
1. **Sub-agents READ**: They can read `_index.md` and memory files for context
2. **Sub-agents WRITE**: They write to `subagent/` directory with unique filenames
3. **Parent consolidates**: The main Claude updates `_index.md` after sub-agents complete

### Benefits
- Sub-agents understand project context before starting work
- Their findings are preserved in memory
- Parallel sub-agents don't conflict (unique filenames)
- Parent can consolidate important findings into decisions/analysis

### Example Sub-Agent Workflow
```
User: "Analyze the security of our auth module using sub-agents"

Claude (parent):
1. Reads _index.md for context
2. Spawns sub-agent with memory instructions:
   "Analyze src/auth/. MEMORY: Read ~/.claude/projects/my-app/_index.md for context.
    Write output to ~/.claude/projects/my-app/subagent/2026-01-20_143000_auth-security.md"
3. Sub-agent reads context, performs analysis, writes findings
4. Claude consolidates findings into _index.md
```

### Automatic Behavior
When memory mode is active and you ask Claude to use sub-agents, it will automatically:
- Include memory context instructions in sub-agent prompts
- Direct sub-agents to write to the `subagent/` directory
- Consolidate results after sub-agents complete

## User Preferences (v1.2.0+)

Claude can learn and remember your preferences over time.

### How It Works

**Three ways Claude learns:**
1. **Explicit**: Tell Claude directly - "I prefer concise explanations"
2. **Observed**: Claude notices patterns and asks - "Should I remember that you prefer code examples first?"
3. **Feedback**: Tell Claude what worked - "That explanation was perfect"

### User Commands

```
/user              # Show your profile
/user update       # Update preferences
/user forget X     # Remove specific information
/user export       # Export for backup/portability
/user import       # Import from backup
```

### Transparency

Claude always announces what it stores:
```
📝 Noted: You prefer concise explanations
```

And references preferences when using them:
```
💭 Based on your preference for code-first explanations, here's the implementation...
```

### Privacy & Control
- You can see everything stored (`/user`)
- You can delete anything (`/user forget`)
- Observations require your confirmation before storing
- Export/import for portability between machines

## Cross-Project Operations (v1.3.0+)

### Accessing Related Projects

When working on a project that relates to others:
1. Check `~/.claude/workspace.md` for relationships
2. Read related project's `_index.md` for context
3. Reference specific decisions or analyses as needed

### Cross-Project Initiatives

For work spanning multiple repos (releases, upgrades):
1. Track in `~/.claude/workspace.md` under Current Initiatives
2. Reference from individual project memories
3. Update initiative status as work progresses

### Example workspace.md

```markdown
# Workspace

## Repository Registry

| Repo Key | Path | Description | Status |
|----------|------|-------------|--------|
| my-app | `~/workspace/my-app` | Main application | Active |
| my-app-api | `~/workspace/my-app-api` | Backend API | Active |
| shared-utils | `~/workspace/shared-utils` | Shared utilities | Active |

## Repository Relationships

### my-app
- **Type**: Frontend Application
- **Framework**: React
- **Dependencies**: my-app-api, shared-utils

## Current Initiatives

### v2.0 Release
- **Status**: In Progress
- **Repos Involved**: my-app, my-app-api
- **Next Steps**: Complete API migration, then frontend updates
```

## Troubleshooting

### Memory mode not activating
- Check that `@MEMORY.md` is in your `~/.claude/CLAUDE.md`
- Verify `~/.claude/MEMORY.md` exists
- Try `/memory status` to see current state

### Lost context after long session
- This is normal! Claude detects it and recovers automatically
- If issues persist, try `/memory rebuild`

### Want to start fresh in a project
```bash
rm -rf ~/.claude/projects/{project-key}/
```
Then `/memory start` again.

### Index seems wrong
```
/memory rebuild
```
This regenerates the index from actual files.

### Sub-agents not using memory
- Ensure memory mode is active (`/memory status`)
- Claude should automatically include memory instructions when spawning sub-agents
- If not, you can explicitly ask: "Use sub-agents with memory integration"

### Sub-agent outputs not appearing in index
- The parent agent consolidates after sub-agents complete
- Check `subagent/` directory directly for raw outputs
- Use `/memory rebuild` to force index regeneration

### Claude not recognizing me in new sessions
- Check that `~/.claude/CLAUDE.md` has the SESSION START PROTOCOL
- Verify `~/.claude/user/profile.md` exists
- Make sure `@USER.md` is referenced in your CLAUDE.md

### Workspace not showing my projects
- Projects are registered when you run `/memory start` in them
- You can manually edit `~/.claude/workspace.md` to add projects
- Run `/workspace` to see current registry

## Migration from v1.2.x

If you have existing `.claude/memory/` directories in projects:

1. **Create project key from directory name**
   ```bash
   # Example: ~/workspace/my_app → my-app
   ```

2. **Move contents to centralized location**
   ```bash
   mkdir -p ~/.claude/projects/my-app
   mv ~/workspace/my_app/.claude/memory/* ~/.claude/projects/my-app/
   ```

3. **Update _session.json** with new `projectKey` and `projectPath` fields

4. **Register in workspace.md**
   Add the project to `~/.claude/workspace.md` Repository Registry

5. **Clean up old directory** (optional)
   ```bash
   rm -rf ~/workspace/my_app/.claude/
   ```

## Version History

### v1.3.0 - Centralized Architecture
- **Breaking**: All project memory now stored at `~/.claude/projects/{project-key}/`
- New `~/.claude/workspace.md` for cross-project context
- New `/workspace` command to view project relationships
- New `project.md` file for project-specific context
- Removed gitignore integration (no longer needed - memory isn't in project dirs)
- Seamless cross-project access without permission prompts
- Updated CLAUDE.md.example to include workspace.md in session protocol

### v1.2.1 - Auto-Recognition
- New `CLAUDE.md.example` with SESSION START PROTOCOL
- Claude automatically reads user profile on every new session
- No command needed for relationship continuity
- Updated installation instructions

### v1.2.0 - User Preference & Relationship Tracking
- New `~/.claude/user/` global profile directory
- Two-tier storage: global profile + project-specific context
- `/user` commands for profile management
- Three-way learning protocol (explicit, observed, feedback)
- Transparency markers for stored observations
- Export/import for profile portability

### v1.1.0 - Sub-Agent Integration
- New `subagent/` directory for sub-agent outputs
- Sub-Agent Memory Protocol with coordination rules
- Template prompts for memory-aware sub-agents
- Parallel sub-agent support with conflict prevention
- Updated `_session.json` with `subagentOutputs` stat

### v1.0.0 - Initial release
- Breadcrumb-based compaction detection
- Per-project data isolation
- Session archiving
- Index auto-management with 20-entry limit
- Recovery via `/memory rebuild`
