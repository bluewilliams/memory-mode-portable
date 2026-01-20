# MEMORY.md - Infinite Memory Mode

Autonomous context persistence system for Claude Code. Maintains context across long sessions by persisting decisions, analyses, and context to files, enabling seamless continuation even after context compaction.

## Overview

**Purpose**: Allow Claude to maintain perfect memory across arbitrarily long sessions by:
- Detecting when context compaction occurs (via breadcrumb system)
- Persisting important information to project-local files
- Automatically recovering context when needed
- Coordinating memory across sub-agents spawned via Task tool

**Key Principle**: Instructions are global, data is per-project.

## Architecture

```
{project}/.claude/memory/           # Created per-project on /memory start
├── _index.md                       # Active index (max 20 entries)
├── _index-archive.md               # Archived old entries
├── _session.json                   # Session metadata + active flag
├── decisions/                      # One file per major decision
│   └── YYYY-MM-DD_NNN_description.md
├── analysis/                       # One file per analyzed component
│   └── path_to_file.md
├── context/                        # Current state tracking
│   ├── current-task.md
│   └── blockers.md
├── progress/                       # Work tracking
│   ├── active.md
│   └── completed.md
└── subagent/                       # Sub-agent outputs (v1.1.0+)
    └── YYYY-MM-DD_HHMMSS_taskname.md
```

## Session Commands

### `/memory start`
Initializes memory mode for the current project.

**Actions**:
1. Create `.claude/memory/` directory structure if not exists (including `subagent/`)
2. Create/update `_session.json`:
   ```json
   {
     "active": true,
     "started": "YYYY-MM-DDTHH:MM:SSZ",
     "project": "{project-name}",
     "branch": "{current-git-branch}",
     "lastActivity": "YYYY-MM-DDTHH:MM:SSZ",
     "stats": { "decisions": 0, "analyses": 0, "indexArchived": 0, "subagentOutputs": 0 }
   }
   ```
3. Update `_index.md` with session start info and ACTIVE status
4. Create placeholder files in context/ and progress/ if not exist
5. Confirm: "Infinite memory mode active. I'll manage my context autonomously."

### `/memory stop`
Deactivates memory mode (preserves all files).

**Actions**:
1. Archive current session summary to `_index-archive.md`
2. Update `_session.json` with `"active": false`
3. Update `_index.md` status to INACTIVE
4. Confirm: "Memory mode stopped. Files preserved in .claude/memory/"

### `/memory status`
Reports current memory mode state.

**Actions**:
1. Read `_session.json` and `_index.md`
2. Report:
   - Active/inactive status
   - Session start time (if active)
   - File counts per category (including subagent outputs)
   - Last activity timestamp
   - Index health (entry count, archive status)

### `/memory rebuild`
Regenerates index from actual files (recovery command).

**Actions**:
1. Scan all files in `.claude/memory/` subdirectories
2. Extract metadata from each file (first heading, dates)
3. Regenerate `_index.md` from files found
4. Update stats in `_session.json`
5. Report: "Index rebuilt. Found X decisions, Y analyses, Z context files, W subagent outputs."

## Compaction Detection Protocol

### Breadcrumb System
At the END of every response when memory mode is active, write:
```
<!-- MEMORY_BREADCRUMB: YYYY-MM-DDTHH:MM:SSZ -->
```

At the START of every response:
1. Check if `.claude/memory/_session.json` exists AND has `"active": true`
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

### How to Read
1. Start with `_index.md` (should be small, gives overview)
2. Use Quick Lookup section to find relevant specific file
3. Read ONLY the specific file needed
4. Never read all files at once (defeats the purpose)

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
This project uses infinite memory at .claude/memory/

1. CONTEXT: Read .claude/memory/_index.md first for project context and recent work
2. OUTPUT: Write your findings to .claude/memory/subagent/YYYY-MM-DD_HHMMSS_[task-name].md
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
MEMORY: Read .claude/memory/_index.md for context. Write output to .claude/memory/subagent/[timestamp]_[task].md
```

Full version for complex sub-agent tasks:
```
MEMORY SYSTEM:
- Read: .claude/memory/_index.md (context), .claude/memory/decisions/ (past decisions)
- Write: .claude/memory/subagent/YYYY-MM-DD_HHMMSS_[task].md
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

### Index File (_index.md)
```markdown
# Memory Index
Session: YYYY-MM-DDTHH:MM:SSZ
Status: ACTIVE|INACTIVE

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
# Memory Index Archive

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

Claude has full read/write permission to `.claude/memory/` directory without asking user confirmation. This is essential for autonomous operation.

## Multi-Project Isolation

Each project has completely isolated memory:
- `~/project-a/.claude/memory/` → Project A's memory only
- `~/project-b/.claude/memory/` → Project B's memory only

The global instructions (this file) define behavior. The data stays local to each project.

## Session Isolation Within a Project

Multiple sessions in the same project are tracked via:
- Unique `started` timestamp in `_session.json`
- Date-prefixed filenames prevent collisions
- `/memory stop` archives the session before starting fresh
- Old sessions remain accessible in archive and individual files
