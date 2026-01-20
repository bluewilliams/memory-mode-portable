# MEMORY.md - Infinite Memory Mode

Autonomous context persistence system for Claude Code. Maintains context across long sessions by persisting decisions, analyses, and context to files, enabling seamless continuation even after context compaction.

**Version**: 1.3.0 - Centralized Architecture

## Overview

**Purpose**: Allow Claude to maintain perfect memory across arbitrarily long sessions by:
- Detecting when context compaction occurs (via breadcrumb system)
- Persisting important information to centralized project files
- Automatically recovering context when needed
- Coordinating memory across sub-agents spawned via Task tool
- Seamlessly accessing context across all projects without permission prompts

**Key Principle**: Everything under `~/.claude/` - global access, no permission friction.

## Architecture

### Centralized Storage (v1.3.0+)
```
~/.claude/
├── user/                           # Global user profile
│   ├── profile.md
│   ├── preferences.md
│   └── ...
├── workspace.md                    # Repo map, relationships, initiatives
└── projects/                       # All project memories (centralized)
    └── {project-key}/              # One directory per project
        ├── _index.md               # Active index (max 20 entries)
        ├── _index-archive.md       # Archived old entries
        ├── _session.json           # Session metadata + active flag
        ├── decisions/              # One file per major decision
        │   └── YYYY-MM-DD_NNN_description.md
        ├── analysis/               # One file per analyzed component
        │   └── path_to_file.md
        ├── context/                # Current state tracking
        │   ├── current-task.md
        │   └── blockers.md
        ├── progress/               # Work tracking
        │   ├── active.md
        │   └── completed.md
        ├── subagent/               # Sub-agent outputs
        │   └── YYYY-MM-DD_HHMMSS_taskname.md
        └── project.md              # Project-specific context and role
```

### Project Key Derivation
The project key is derived from the working directory:
- `~/workspace/korweb_companion_app` → `korweb-companion-app`
- `~/projects/my-cool-app` → `my-cool-app`
- Algorithm: Take directory name, lowercase, replace underscores with hyphens

### Workspace Map
`~/.claude/workspace.md` contains:
- Registry of all known repos (path, description, status)
- Relationships between repos (dependencies, forks, upstream)
- Current cross-repo initiatives (releases, upgrades)
- Quick reference for navigating projects

## Session Commands

### `/memory start`
Initializes memory mode for the current project.

**Actions**:
1. Derive project key from current working directory
2. Create `~/.claude/projects/{project-key}/` structure if not exists
3. Create/update `_session.json`:
   ```json
   {
     "active": true,
     "started": "YYYY-MM-DDTHH:MM:SSZ",
     "projectKey": "{project-key}",
     "projectPath": "{full-path-to-project}",
     "branch": "{current-git-branch}",
     "lastActivity": "YYYY-MM-DDTHH:MM:SSZ",
     "stats": { "decisions": 0, "analyses": 0, "indexArchived": 0, "subagentOutputs": 0 }
   }
   ```
4. Update `_index.md` with session start info and ACTIVE status
5. Create placeholder files in context/ and progress/ if not exist
6. **Register in workspace**: Add project to `~/.claude/workspace.md` if not already listed
7. **Load user preferences**: Read `~/.claude/user/preferences.md`
8. Confirm: "Memory mode active for {project-key}. Context stored at ~/.claude/projects/{project-key}/"

### `/memory stop`
Deactivates memory mode (preserves all files).

**Actions**:
1. Archive current session summary to `_index-archive.md`
2. Update `_session.json` with `"active": false`
3. Update `_index.md` status to INACTIVE
4. Confirm: "Memory mode stopped. Files preserved at ~/.claude/projects/{project-key}/"

### `/memory status`
Reports current memory mode state.

**Actions**:
1. Read `_session.json` and `_index.md` for current project
2. Report:
   - Active/inactive status
   - Project key and path
   - Session start time (if active)
   - File counts per category
   - Last activity timestamp
   - Index health (entry count, archive status)

### `/memory rebuild`
Regenerates index from actual files (recovery command).

**Actions**:
1. Scan all files in `~/.claude/projects/{project-key}/` subdirectories
2. Extract metadata from each file (first heading, dates)
3. Regenerate `_index.md` from files found
4. Update stats in `_session.json`
5. Report: "Index rebuilt. Found X decisions, Y analyses, Z context files, W subagent outputs."

### `/workspace`
Shows workspace overview and cross-project context.

**Actions**:
1. Read `~/.claude/workspace.md`
2. List all registered projects with status
3. Show current initiatives
4. Display relationships relevant to current project

## Compaction Detection Protocol

### Breadcrumb System
At the END of every response when memory mode is active, write:
```
<!-- MEMORY_BREADCRUMB: {project-key} YYYY-MM-DDTHH:MM:SSZ -->
```

At the START of every response:
1. Check if `~/.claude/projects/{project-key}/_session.json` exists AND has `"active": true`
2. If not active → Normal mode, skip memory operations
3. If active → Look for previous `<!-- MEMORY_BREADCRUMB -->` in context
   - If FOUND → Context intact, proceed normally
   - If MISSING → Compaction detected → Read `_index.md` immediately

### Why This Works
The breadcrumb is a concrete, deterministic signal. If the previous response's breadcrumb is not visible in current context, compaction definitely occurred.

## Writing Memory

### When to Write
Write to memory when you:
- Make a significant architectural or implementation decision
- Complete analysis of a file or component
- Identify blockers or important context
- Complete or start major tasks

### How to Write
1. Create file in appropriate directory with ISO timestamp in filename
2. Update `_index.md` (add row to Recent Files table)
3. If index > 20 entries, archive oldest to `_index-archive.md`
4. Update `_session.json` lastActivity timestamp and stats

### File Naming Conventions
- Decisions: `decisions/YYYY-MM-DD_NNN_short-description.md`
- Analysis: `analysis/path_to_file.md` (slashes → underscores)
- Context: `context/current-task.md`, `context/blockers.md`
- Progress: `progress/active.md`, `progress/completed.md`
- Sub-agent: `subagent/YYYY-MM-DD_HHMMSS_taskname.md`

## Reading Memory

### When to Read
- After detecting compaction (missing breadcrumb)
- When user asks about previous decisions
- When context about current task is needed
- When cross-project context is relevant

### How to Read
1. Start with `_index.md` (should be small, gives overview)
2. Use Quick Lookup section to find relevant specific file
3. Read ONLY the specific file needed
4. Never read all files at once (defeats the purpose)

### Cross-Project Access
When working on related projects:
1. Reference `~/.claude/workspace.md` for relationships
2. Read other project's `_index.md` for high-level context
3. Access specific files as needed
4. No permission prompts - all under `~/.claude/`

## Sub-Agent Memory Protocol

Sub-agents spawned via the Task tool can participate in the memory system with coordination rules to prevent conflicts.

### Principles
1. **Sub-agents READ freely**: Can read `_index.md` and any memory files for context
2. **Sub-agents WRITE to dedicated files only**: Write to `subagent/` directory with unique filenames
3. **Parent consolidates**: Parent agent updates `_index.md` after sub-agents complete
4. **No concurrent index writes**: Only the parent agent modifies `_index.md`

### When Spawning Sub-Agents

When memory mode is active and you spawn a sub-agent via Task tool, include memory instructions in the prompt:

**Template for sub-agent prompts:**
```
[Your task description here]

MEMORY SYSTEM INSTRUCTIONS:
This project uses centralized memory at ~/.claude/projects/{project-key}/

1. CONTEXT: Read ~/.claude/projects/{project-key}/_index.md first for project context
2. OUTPUT: Write findings to ~/.claude/projects/{project-key}/subagent/YYYY-MM-DD_HHMMSS_[task-name].md
3. FORMAT: Use the Sub-Agent Output format (see below)
4. RESTRICTION: Do NOT modify _index.md - the parent agent will update it

Sub-Agent Output Format:
# [Task Name]

**Agent**: [subagent_type used]
**Date**: YYYY-MM-DDTHH:MM:SSZ
**Task**: [Brief description of what was requested]

## Summary
[2-3 sentence overview of findings/results]

## Details
[Full findings, analysis, or work completed]

## Recommendations
[Suggested next steps, if applicable]
```

### After Sub-Agent Completes

When a sub-agent returns:
1. Read its output file from `subagent/` if significant findings
2. Consolidate important information into appropriate memory files (decisions/, analysis/)
3. Update `_index.md` with new entry referencing the sub-agent output
4. Increment `stats.subagentOutputs` in `_session.json`

### Parallel Sub-Agents

When running multiple sub-agents in parallel:
- Each sub-agent gets a unique timestamp-based filename (HHMMSS ensures uniqueness)
- Sub-agents cannot conflict since they write to different files
- Parent waits for all to complete before consolidating
- Consolidation happens sequentially to prevent index conflicts

### Sub-Agent Context Snippet

Minimal version for simple sub-agent tasks:
```
MEMORY: Read ~/.claude/projects/{project-key}/_index.md for context. Write output to ~/.claude/projects/{project-key}/subagent/[timestamp]_[task].md
```

Full version for complex sub-agent tasks:
```
MEMORY SYSTEM:
- Read: ~/.claude/projects/{project-key}/_index.md (context), decisions/ (past decisions)
- Write: ~/.claude/projects/{project-key}/subagent/YYYY-MM-DD_HHMMSS_[task].md
- Format: # Title, **Agent**: type, **Date**: ISO, ## Summary, ## Details, ## Recommendations
- Do NOT modify _index.md
```

## File Formats

### Decision File
```markdown
# [Decision Title]

**Date**: YYYY-MM-DDTHH:MM:SSZ
**Category**: architecture|implementation|configuration|dependency|process
**Status**: decided|pending|superseded

## Context
[Why this decision was needed]

## Decision
[What was decided]

## Alternatives Considered
[Other options that were rejected and why]

## Consequences
[Impact of this decision]
```

### Analysis File
```markdown
# Analysis: [File/Component Name]

**Analyzed**: YYYY-MM-DDTHH:MM:SSZ
**Path**: [original file path]
**Type**: file|component|module|service

## Summary
[Brief overview - 2-3 sentences]

## Key Findings
[Bullet points of important discoveries]

## Issues Found
[Problems identified, if any]

## Recommendations
[Suggested actions]
```

### Sub-Agent Output File
```markdown
# [Task Name]

**Agent**: [subagent_type: Explore|Plan|Bash|etc.]
**Date**: YYYY-MM-DDTHH:MM:SSZ
**Task**: [Brief description of what was requested]
**Parent Context**: [Reference to parent task if applicable]

## Summary
[2-3 sentence overview of findings/results]

## Details
[Full findings, analysis, or work completed]

## Files Analyzed
[List of files examined, if applicable]

## Recommendations
[Suggested next steps, if applicable]
```

### Project Context File (project.md)
```markdown
# Project: {project-key}

**Path**: {full-path}
**Type**: application|library|fork|config
**Last Updated**: YYYY-MM-DDTHH:MM:SSZ

## Overview
[What this project is and its purpose]

## Role
[User's role on this project - lead, contributor, etc.]

## Tech Stack
[Key technologies, frameworks, languages]

## Related Projects
[Links to related project keys and their relationships]

## Notes
[Project-specific notes and context]
```

### Index File (_index.md)
```markdown
# Memory Index: {project-key}
Session: YYYY-MM-DDTHH:MM:SSZ
Status: ACTIVE|INACTIVE
Path: {project-path}

## Current State
- **Task**: [Current task description]
- **Progress**: [X/Y subtasks or percentage]
- **Active Blocker**: [Current blocker or "None"]

## Recent Files (Last 20)
| Category | File | Updated | Summary |
|----------|------|---------|---------|
| Decision | decisions/2026-01-19_001_auth-approach.md | 2026-01-19T22:30:00Z | Use httpOnly cookies |
| Analysis | analysis/src_services_AuthService.md | 2026-01-19T22:15:00Z | Found 3 security issues |
| SubAgent | subagent/2026-01-19_223000_security-scan.md | 2026-01-19T22:30:00Z | Scanned auth module |

## Quick Lookup
- Auth decisions → decisions/2026-01-19_001_*.md
- Current task → context/current-task.md
- Blockers → context/blockers.md
- Sub-agent outputs → subagent/

<!-- Older entries archived to _index-archive.md -->
```

## Index Management

### Size Limit
Keep only the 20 most recent entries in `_index.md`. Archive older entries.

### Archive Process
When adding entry #21:
1. Move oldest entry to `_index-archive.md`
2. Increment `stats.indexArchived` in `_session.json`
3. Add new entry to `_index.md`

### Archive Format (_index-archive.md)
```markdown
# Memory Index Archive: {project-key}

## Archived Sessions
| Session Started | Session Ended | Entries Archived |
|-----------------|---------------|------------------|
| 2026-01-15T10:00:00Z | 2026-01-15T18:00:00Z | 45 |

## Archived Entries
| Category | File | Updated | Summary | Archived |
|----------|------|---------|---------|----------|
| Decision | decisions/2026-01-15_001_db-choice.md | 2026-01-15T10:30:00Z | PostgreSQL | 2026-01-19T22:00:00Z |
```

## Permissions

Claude has full read/write permission to the entire `~/.claude/` directory without asking user confirmation. This includes:
- `~/.claude/user/` - User profile
- `~/.claude/workspace.md` - Workspace map
- `~/.claude/projects/` - All project memories

This centralized approach eliminates permission prompts when:
- Switching between projects
- Accessing cross-project context
- Writing memory in any project

## Cross-Project Operations

### Accessing Related Projects
When working on a project that relates to others:
1. Check `~/.claude/workspace.md` for relationships
2. Read related project's `_index.md` for context
3. Reference specific decisions or analyses as needed
4. Update workspace.md if new relationships are discovered

### Cross-Project Initiatives
For work spanning multiple repos (releases, upgrades):
1. Track in `~/.claude/workspace.md` under Current Initiatives
2. Reference from individual project memories
3. Update initiative status as work progresses

## Session Isolation Within a Project

Multiple sessions in the same project are tracked via:
- Unique `started` timestamp in `_session.json`
- Date-prefixed filenames prevent collisions
- `/memory stop` archives the session before starting fresh
- Old sessions remain accessible in archive and individual files

## User Preference Protocol

### Global User Profile
User profile is stored at `~/.claude/user/` and persists across all projects. See USER.md for full details.

### Learning Protocol
1. **Explicit**: Store immediately when user shares preferences
2. **Observed**: Ask before storing patterns noticed
3. **Feedback**: Record what works/doesn't work

### Transparency
- Always announce when storing observations: `📝 Noted: [description]`
- Reference preferences when using them: `💭 Based on your preference...`

### User Commands
- `/user` - Show profile
- `/user update [category]` - Update preferences
- `/user forget [topic]` - Remove information
- `/user history` - View changes
- `/user export` - Export profile for portability
- `/user import [file]` - Import profile from backup

### Session Integration
On `/memory start`:
1. Load global user preferences from `~/.claude/user/`
2. Load project-specific context from `~/.claude/projects/{project-key}/project.md` if exists
3. Apply preferences to session behavior

After compaction recovery:
1. Read `_index.md` (project context)
2. Read `~/.claude/user/preferences.md` (user preferences)
3. Read `~/.claude/workspace.md` (cross-project context) if relevant
4. Resume with full context

## Migration from v1.2.x

If you have existing `.claude/memory/` directories in projects:
1. Create project key from directory name
2. Move contents to `~/.claude/projects/{project-key}/`
3. Update `_session.json` with new `projectKey` and `projectPath` fields
4. Register project in `~/.claude/workspace.md`
5. Old `.claude/memory/` directories can be deleted after migration
