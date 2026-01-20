# Infinite Memory Mode for Claude Code

Autonomous context persistence system that allows Claude to maintain perfect memory across arbitrarily long sessions.

## What This Does

When enabled, Claude will:
- Automatically detect when context compaction occurs
- Persist important decisions, analyses, and context to files
- Recover seamlessly when context is lost
- Maintain separate memory for each project you work on
- **Coordinate memory across sub-agents** (v1.1.0+)

**From your perspective**: Work normally. Claude never forgets.

## Installation

### Quick Install (Copy-Paste)

1. **Copy `MEMORY.md` to your global Claude config:**
   ```bash
   cp ~/.claude/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   ```

2. **Add reference to your `~/.claude/CLAUDE.md`:**

   Open `~/.claude/CLAUDE.md` and add this line:
   ```
   @MEMORY.md
   ```

   If you don't have a `CLAUDE.md` file yet, create one:
   ```bash
   echo "@MEMORY.md" > ~/.claude/CLAUDE.md
   ```

3. **Done!** Start using it in any project with `/memory start`

### Fresh Claude Installation

If you're setting up Claude Code from scratch:

1. **Create the global config directory:**
   ```bash
   mkdir -p ~/.claude
   ```

2. **Copy the memory mode file:**
   ```bash
   cp /path/to/memory-mode-portable/MEMORY.md ~/.claude/MEMORY.md
   ```

3. **Create or update CLAUDE.md:**
   ```bash
   # If you have no other Claude config:
   echo "@MEMORY.md" > ~/.claude/CLAUDE.md

   # Or if you have existing config, add the reference:
   echo "@MEMORY.md" >> ~/.claude/CLAUDE.md
   ```

### Sharing With a Friend

Send them:
1. This `memory-mode-portable/` folder (or just `MEMORY.md` and this `README.md`)
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
        └── subagent/           # Sub-agent outputs (v1.1.0+)
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

## File Structure Reference

```
~/.claude/                          # Global config (shared across projects)
├── CLAUDE.md                       # References @MEMORY.md
└── MEMORY.md                       # Memory mode instructions

~/any-project/.claude/memory/       # Per-project data (auto-created)
├── _index.md
├── _session.json
├── decisions/
├── analysis/
├── context/
├── progress/
└── subagent/                       # Sub-agent outputs
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
