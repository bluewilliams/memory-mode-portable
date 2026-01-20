# Infinite Memory Mode for Claude Code

Autonomous context persistence system that allows Claude to maintain perfect memory across arbitrarily long sessions.

## What This Does

When enabled, Claude will:
- Automatically detect when context compaction occurs
- Persist important decisions, analyses, and context to files
- Recover seamlessly when context is lost
- Maintain separate memory for each project you work on
- **Coordinate memory across sub-agents** (v1.1.0+)
- **Remember your preferences across all projects** (v1.2.0+)

**From your perspective**: Work normally. Claude never forgets.

## Installation

### Quick Install (Copy-Paste)

1. **Copy config files to your global Claude config:**
   ```bash
   cp ~/.claude/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   cp ~/.claude/memory-mode-portable/USER.md ~/.claude/USER.md
   ```

2. **Create the user profile directory:**
   ```bash
   mkdir -p ~/.claude/user
   ```

3. **Add references to your `~/.claude/CLAUDE.md`:**

   Open `~/.claude/CLAUDE.md` and add these lines:
   ```
   @MEMORY.md
   @USER.md
   ```

   If you don't have a `CLAUDE.md` file yet, create one:
   ```bash
   printf "@MEMORY.md\n@USER.md\n" > ~/.claude/CLAUDE.md
   ```

4. **Done!** Start using it in any project with `/memory start`

### Fresh Claude Installation

If you're setting up Claude Code from scratch:

1. **Create the global config directories:**
   ```bash
   mkdir -p ~/.claude ~/.claude/user
   ```

2. **Copy the config files:**
   ```bash
   cp /path/to/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   cp /path/to/memory-mode-portable/USER.md ~/.claude/USER.md
   ```

3. **Create or update CLAUDE.md:**
   ```bash
   # If you have no other Claude config:
   printf "@MEMORY.md\n@USER.md\n" > ~/.claude/CLAUDE.md

   # Or if you have existing config, add the references:
   printf "@MEMORY.md\n@USER.md\n" >> ~/.claude/CLAUDE.md
   ```

### Sharing With a Friend

Send them:
1. This `memory-mode-portable/` folder (includes `MEMORY.md`, `USER.md`, and this `README.md`)
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
- Create `.claude/memory/` in your project directory
- Initialize session tracking
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

### Rebuilding Index (Recovery)
```
/memory rebuild
```

If the index gets out of sync, this regenerates it from actual files.

## How It Works

### Data Storage
Each project gets its own memory directory:
```
your-project/
└── .claude/
    └── memory/
        ├── _index.md           # Quick lookup index
        ├── _index-archive.md   # Archived old entries
        ├── _session.json       # Session state
        ├── decisions/          # Major decisions made
        ├── analysis/           # File/component analyses
        ├── context/            # Current task & blockers
        ├── progress/           # Work tracking
        ├── subagent/           # Sub-agent outputs (v1.1.0+)
        └── user/               # Project-specific user context (v1.2.0+)
```

### Global User Profile (v1.2.0+)
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
   "Analyze src/auth/. MEMORY: Read .claude/memory/_index.md for context.
    Write output to .claude/memory/subagent/2026-01-20_143000_auth-security.md"
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

## Gitignore Integration (v1.2.0+)

On `/memory start`, Claude will ask if you want to add `.claude/memory/` to your `.gitignore` to prevent accidentally committing session context.

Options:
- **Yes**: Add to this project
- **No**: Skip for now
- **Always**: Remember preference, auto-add for all projects
- **Never ask again**: Remember preference, never prompt

## File Structure Reference

```
~/.claude/                          # Global config (shared across projects)
├── CLAUDE.md                       # References @MEMORY.md and @USER.md
├── MEMORY.md                       # Memory mode instructions
├── USER.md                         # User preference instructions (v1.2.0+)
└── user/                           # Global user profile (v1.2.0+)
    ├── profile.md
    ├── preferences.md
    ├── communication.md
    ├── technical.md
    ├── observations.md
    └── feedback.md

~/any-project/.claude/memory/       # Per-project data (auto-created)
├── _index.md
├── _session.json
├── decisions/
├── analysis/
├── context/
├── progress/
├── subagent/                       # Sub-agent outputs
└── user/                           # Project-specific user context
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
rm -rf your-project/.claude/memory/
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

## Version History

### v1.2.0 - User Preference & Relationship Tracking
- New `~/.claude/user/` global profile directory
- Two-tier storage: global profile + project-specific context
- `/user` commands for profile management
- Three-way learning protocol (explicit, observed, feedback)
- Transparency markers for stored observations
- Gitignore integration on `/memory start`
- Export/import for profile portability
- New `user/` subdirectory in project memory

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
