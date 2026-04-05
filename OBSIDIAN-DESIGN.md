# Obsidian Backend Design — Memory Mode Portable v2.0

**Status**: Design Draft
**Date**: 2026-04-05
**Author**: Blue Williams + Claude

---

## Executive Summary

Memory Mode Portable v2.0 introduces an optional Obsidian vault backend that transforms Claude's memory from private machine state into a **dual-purpose knowledge base** — fully functional for Claude's context recovery AND browsable/searchable/graphable by the user in Obsidian.

The user can also **share files with Claude** (PDFs, images, meeting notes, reference docs) by dropping them into the vault. Claude creates companion notes that link them into the knowledge graph, making them discoverable in future sessions.

The default flat-file backend remains available. Backend selection is a one-time configuration choice.

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Configuration System](#2-configuration-system)
3. [Vault Structure](#3-vault-structure)
4. [Note Formats](#4-note-formats)
5. [Tag Taxonomy](#5-tag-taxonomy)
6. [Linking Strategy & Graph Design](#6-linking-strategy--graph-design)
7. [Obsidian Templates](#7-obsidian-templates)
8. [Dataview Queries & Dashboards](#8-dataview-queries--dashboards)
9. [Shared Resources System](#9-shared-resources-system)
10. [Session & State Management](#10-session--state-management)
11. [Hook System Updates](#11-hook-system-updates)
12. [Installer Updates](#12-installer-updates)
13. [MEMORY.md Instruction Updates](#13-memorymd-instruction-updates)
14. [Sub-Agent Protocol Updates](#14-sub-agent-protocol-updates)
15. [Migration from v1.x](#15-migration-from-v1x)
16. [Recommended Obsidian Plugins](#16-recommended-obsidian-plugins)
17. [File Inventory](#17-file-inventory)
18. [Tiered Retrieval System](#18-tiered-retrieval-system)
19. [Obsidian Search Literacy for Claude](#19-obsidian-search-literacy-for-claude)
20. [Relationship & Continuity Memory](#20-relationship--continuity-memory)

---

## 1. Design Principles

### Dual-Purpose First
Every note Claude writes must be **useful to both Claude and the user**. No machine-only gibberish. Human-readable titles, clear structure, meaningful tags.

### Obsidian-Native
Use Obsidian's strengths: YAML frontmatter, `[[wikilinks]]`, `#tags`, graph view, Dataview queries, templates. Don't fight the tool — embrace its conventions.

### Graph-Optimized
The knowledge graph should be **meaningful at a glance**. Projects are hubs. Decisions chain together. Resources connect to the contexts where they matter. Orphan notes are failures.

### Shallow Hierarchy, Rich Links
Obsidian works best with flat-ish folder structures + dense linking. Two levels of folders max. Let tags and links do the organizing, not nested directories.

### Backward Compatible
The default backend (`~/.claude/projects/`) works exactly as v1.x. Obsidian is opt-in. Both backends share the same session commands (`/memory start`, `/memory stop`, etc.).

### Shared Knowledge Space
The vault is not just Claude's memory — it's a **shared workspace**. The user can drop files in, write their own notes, and Claude will discover and link to them. Claude can also save files the user shares during sessions.

---

## 2. Configuration System

### memory-config.json

New file at `~/.claude/memory-config.json`. Controls backend selection and settings.

### Deployment Modes

There are two ways to deploy the Obsidian backend:

#### Mode 1: Subfolder in an Existing Vault (Recommended)

Claude's memory lives inside a subfolder of a vault you already use. This is the best option because your existing notes and Claude's memory share the same graph — you can wikilink between them freely.

```json
{
  "version": "2.0.0",
  "backend": "obsidian",
  "obsidian": {
    "vaultPath": "~/Documents/KorTerra Vault/KorTerra",
    "basePath": "Claude",
    "features": {
      "dataview": true,
      "templates": true
    }
  },
  "default": {
    "basePath": "~/.claude/projects"
  }
}
```

With this config, all Claude memory lives at `~/Documents/KorTerra Vault/KorTerra/Claude/`. Claude treats `Claude/` as its root — so `Decisions/` means `Claude/Decisions/` on disk. But wikilinks to notes *outside* the base path work normally, so Claude can link to your Jira notes and you can link to Claude's decisions.

#### Mode 2: Dedicated Vault

A standalone vault used only for Claude memory. Cleaner separation, but no cross-linking with your other notes.

```json
{
  "version": "2.0.0",
  "backend": "obsidian",
  "obsidian": {
    "vaultPath": "~/Obsidian/ClaudeMind",
    "basePath": "",
    "features": {
      "dataview": true,
      "templates": true
    }
  },
  "default": {
    "basePath": "~/.claude/projects"
  }
}
```

When `basePath` is empty or omitted, Claude writes directly to the vault root.

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | string | — | Config schema version |
| `backend` | `"default"` \| `"obsidian"` | `"default"` | Active storage backend |
| `obsidian.vaultPath` | string | — | Path to the Obsidian vault root (must contain `.obsidian/`) |
| `obsidian.basePath` | string | `""` | Subfolder within the vault for Claude's memory. Empty = vault root |
| `obsidian.features.dataview` | bool | `true` | Generate Dataview-compatible frontmatter |
| `obsidian.features.templates` | bool | `true` | Install Obsidian template files |
| `default.basePath` | string | `~/.claude/projects` | Path for default flat-file backend |

### Path Resolution

All paths in the system resolve through this logic:

```
VAULT_ROOT = obsidian.vaultPath            (e.g., ~/Documents/KorTerra Vault/KorTerra)
CLAUDE_ROOT = VAULT_ROOT / obsidian.basePath  (e.g., .../KorTerra/Claude)
STATE_DIR = CLAUDE_ROOT / .claude-state       (e.g., .../Claude/.claude-state)

Note paths:
  Decisions/     → CLAUDE_ROOT/Decisions/
  Sessions/      → CLAUDE_ROOT/Sessions/
  Projects/      → CLAUDE_ROOT/Projects/
  etc.

Wikilinks to notes INSIDE Claude root:
  [[Claude/Decisions/2026-04-05 Some Decision]]
  or with aliases: [[Some Decision]]

Wikilinks to notes OUTSIDE Claude root (user's own notes):
  [[Jira/KA-6135]]
  [[Daily Note/2026-04-05]]
```

### Vault Discovery (during install)

The installer scans for existing vaults in this order:

1. **Explicit**: User provides path via argument or prompt
2. **Environment variable**: `CLAUDE_OBSIDIAN_VAULT`
3. **Auto-scan** (searches common locations + recursive `.obsidian/` detection):
   - `~/Documents/` (depth 3)
   - `~/Obsidian/` (depth 2)
   - `~/vaults/` (depth 2)
   - `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/` (depth 3)
4. **Found vaults are listed** and user picks one, or provides a new path

Example installer output:
```
Found existing Obsidian vaults:
  1) ~/Documents/KorTerra Vault/KorTerra  (has: daily-notes, templates, sync)
  2) Create a new dedicated vault

Your choice [1]: 1

Claude memory subfolder name [Claude]: Claude

✓ Will create Claude/ inside your KorTerra vault
  Path: ~/Documents/KorTerra Vault/KorTerra/Claude/
```

### Validation

On install:
- Verify vault path contains `.obsidian/` (confirms it's a real vault)
- Verify path is writable
- If `basePath` subfolder doesn't exist, create it
- If `basePath` subfolder already exists, warn and ask to confirm (preserves existing files)
- Detect enabled plugins (templates, daily-notes, dataview) and note which are missing
- Detect if Obsidian Sync is enabled — not a blocker, just inform user that writes may have brief sync delays

---

## 3. Vault Structure

### Subfolder Mode (existing vault)

This is the recommended layout. Claude's memory lives inside a `Claude/` subfolder of the user's existing vault, coexisting with their own folders.

```
~/Documents/KorTerra Vault/KorTerra/     # Existing vault root
├── .obsidian/                           # Obsidian config (already exists)
├── 0 Inbox/                             # User's existing folders...
├── Daily Note/                          # User's daily notes
├── Jira/                                # User's Jira notes
├── Assets/                              # User's assets
├── ...                                  # Other user content
│
└── Claude/                              # ← CLAUDE_ROOT (obsidian.basePath)
    ├── .claude-state/                   # Machine-readable state (hidden from Obsidian)
    │   └── {project-key}/              # Per-project machine state
    │       ├── session.json             # Session metadata (active, branch, stats)
    │       └── recent.md               # Hot cache for compaction recovery
    │
    ├── _Templates/                      # Obsidian templates (prefixed _ to sort first)
    │   ├── Decision.md
    │   ├── Analysis.md
    │   ├── Session Log.md
    │   ├── Project.md
    │   ├── Progress.md
    │   ├── Resource.md
    │   └── Sub-Agent Output.md
    │
    ├── _Dashboard.md                    # Main MOC — Dataview-powered overview
│
├── Projects/                            # One note per project
│   ├── memory-mode-portable.md
│   ├── bedtime-buddy.md
│   └── korterra-mobile.md
│
├── Decisions/                           # All decisions, across all projects
│   ├── 2026-04-05 Use Obsidian as memory backend.md
│   └── 2026-01-19 Auth approach for bedtime-buddy.md
│
├── Analysis/                            # All analyses
│   ├── AuthService deep dive.md
│   └── Hook performance analysis.md
│
├── Sessions/                            # Session logs (one per project per day)
│   ├── 2026-04-05 memory-mode-portable.md
│   └── 2026-04-04 bedtime-buddy.md
│
├── Progress/                            # Active work tracking (one per project)
│   ├── memory-mode-portable.md
│   └── bedtime-buddy.md
│
├── Resources/                           # User-shared files + Claude-saved files
│   ├── _Resource Index.md               # MOC for all resources
│   ├── PDFs/                            # Raw PDF files
│   ├── Images/                          # Screenshots, diagrams
│   ├── Documents/                       # Word docs, text files, exports
│   ├── Snippets/                        # Code snippets, config examples
│   └── References/                      # Reference notes (written, not binary files)
│
├── People/                              # People notes
│   ├── Blue Williams.md                 # User's own profile
│   └── _Preferences.md                  # User's working preferences (Claude reads this)
│
├── Sub-Agents/                          # Sub-agent output (kept separate for cleanliness)
│   └── 2026-04-05 143022 security-scan.md
│
├── Workspace.md                         # Cross-project map and relationships
│
└── Daily/                               # Optional: daily notes integration
    └── 2026-04-05.md                    # Auto-links to sessions, decisions made that day
```

### Key Design Decisions

**Why a subfolder (`Claude/`) inside an existing vault?**
The user likely already has an Obsidian vault with their own notes (Jira tickets, daily notes, meeting notes, leadership docs). Putting Claude's memory alongside those notes means:
- **One graph** — Claude's decisions and the user's Jira notes are all connected
- **Cross-linking** — A Claude decision can reference `[[Jira/KA-6135]]`, and a Jira note can reference `[[Claude/Decisions/2026-04-05 Auth approach]]`
- **One sync** — If the user has Obsidian Sync, it covers Claude's notes automatically
- **No vault switching** — Everything in one place
- The `Claude/` prefix keeps things tidy without polluting the vault root

**Why cross-project folders (not per-project)?**
Decisions, analyses, and sessions live in shared top-level folders, not nested under each project. This is intentional:
- Graph view shows connections **across** projects
- You can see all recent decisions regardless of project
- Dataview queries work naturally without path gymnastics
- Project notes act as hubs that link inward

**Why `.claude-state/` is hidden?**
Machine-readable JSON (session state, activity tracking) is needed by hooks and Claude's auto-activation logic, but it's not human-interesting. The dot-prefix hides it from Obsidian's file explorer. Obsidian ignores dotfiles by default.

**Why `_Templates/` and `_Dashboard.md` are prefixed?**
Underscore-prefixed items sort to the top in Obsidian's file explorer, making them easy to find. It's a common Obsidian convention for meta-notes.

**Cross-linking between Claude notes and user notes**
Claude can link to any note in the vault, not just notes inside `Claude/`. For example:
```markdown
## Related
- [[Claude/Projects/bedtime-buddy]]           ← Claude's project note
- [[Jira/KA-6135]]                             ← User's Jira note
- [[Daily Note/2026-04-05]]                    ← User's daily note
```
This is the real power of the existing-vault approach — the knowledge graph spans everything.

---

## 4. Note Formats

Every note uses YAML frontmatter (Obsidian-native, Dataview-queryable) + wikilinks + tags.

### 4.1 Decision Note

**Location**: `Decisions/{date} {descriptive title}.md`
**Replaces**: `decisions/YYYY-MM-DD_NNN_short-description.md`

```markdown
---
type: decision
project: "[[Claude/Projects/memory-mode-portable]]"
date: 2026-04-05
status: decided
category: architecture
tags:
  - decision
  - architecture
  - obsidian
aliases:
  - obsidian backend decision
---

# Use Obsidian as Memory Backend

## Context
[[Claude/Projects/memory-mode-portable]] currently writes memory to flat files at
`~/.claude/projects/`. These files are only useful to Claude.

## Decision
Implement Obsidian vault as an optional storage backend, making AI memory
a dual-purpose knowledge base the user can browse, search, and extend.

## Alternatives Considered
- **Keep flat files**: Simple but not useful as a human knowledge base
- **Notion API**: Requires internet, rate-limited, vendor lock-in
- **LogSeq**: Similar concept but smaller ecosystem and less plugin support

## Consequences
- Memory becomes a browsable, searchable knowledge graph
- Users can add their own notes that Claude can reference
- Requires Obsidian as optional (not mandatory) dependency
- More complex installer with vault configuration

## Related
- [[Claude/Sessions/2026-04-05 memory-mode-portable]]
- [[Claude/Progress/memory-mode-portable]]
```

### 4.2 Analysis Note

**Location**: `Analysis/{descriptive title}.md`
**Replaces**: `analysis/path_to_file.md`

```markdown
---
type: analysis
project: "[[Claude/Projects/bedtime-buddy]]"
date: 2026-01-19
path: src/services/AuthService.ts
component: AuthService
tags:
  - analysis
  - security
  - authentication
---

# AuthService Deep Dive

## Summary
Analyzed the authentication service for security issues. Found 3 vulnerabilities
related to token storage and CSRF protection.

## Key Findings
- Session tokens stored in localStorage (XSS-vulnerable)
- No CSRF protection on auth endpoints
- Token refresh logic has a race condition

## Issues

| Severity | Issue | Location |
|----------|-------|----------|
| High | XSS via localStorage tokens | `AuthService.ts:45` |
| Medium | Missing CSRF middleware | `auth.routes.ts:12` |
| Low | Token refresh race condition | `AuthService.ts:89` |

## Recommendations
- Migrate to httpOnly cookies — see [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]]
- Add CSRF middleware to all state-changing routes
- Implement mutex on token refresh

## Related
- [[Claude/Projects/bedtime-buddy]]
- [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]]
```

### 4.3 Session Log

**Location**: `Sessions/{date} {project-name}.md`
**Replaces**: `context/current-task.md` + `context/blockers.md`

One session note per project per day. Updated throughout the day. This is Claude's primary working note — what it's doing right now.

```markdown
---
type: session
project: "[[Claude/Projects/memory-mode-portable]]"
date: 2026-04-05
branch: main
status: active
tags:
  - session
---

# Session: memory-mode-portable (2026-04-05)

## Current Task
Designing Obsidian backend integration for v2.0.

## Progress
- [x] Explored entire codebase
- [x] Discussed approach with Blue
- [x] Designed vault structure and note formats
- [ ] Writing comprehensive design document
- [ ] Review with Blue

## Blockers
None currently.

## Decisions Made This Session
- [[Claude/Decisions/2026-04-05 Use Obsidian as memory backend]]

## Notes
Blue wants the vault to be a true shared workspace — not just AI memory.
He can drop files (PDFs, docs, images) into Resources/ and Claude will
create companion notes linking them into the knowledge graph.

## Key Context for Recovery
If reading this after compaction: we are mid-design on the Obsidian backend.
The design document is at `OBSIDIAN-DESIGN.md` in the repo. Blue has approved
the general direction. Focus on completing the design doc.
```

### 4.4 Project Note

**Location**: `Projects/{project-name}.md`
**Replaces**: `project.md` in each project directory

```markdown
---
type: project
path: ~/workspace/memory-mode-portable
repo: https://github.com/bluewilliams/memory-mode-portable
status: active
version: 1.6.0
stack:
  - bash
  - markdown
  - shell-hooks
  - json
tags:
  - project
  - open-source
  - ai-tools
aliases:
  - memory mode
  - infinite memory
---

# memory-mode-portable

## Overview
Portable infinite memory system for Claude Code. Maintains context across
sessions via file-based persistence with auto-save hooks and auto-activation.

## Role
Blue is the creator and sole maintainer. Open source on GitHub.

## Tech Stack
- **Core**: Bash scripts, Markdown instruction files
- **Hooks**: Shell scripts (PostToolUse, UserPromptSubmit, PreCompact)
- **Config**: JSON (settings.json, session.json, memory-config.json)
- **Docs**: Markdown with YAML frontmatter

## Current Initiative
v2.0 — Obsidian backend integration

## Related Projects
- [[Claude/Projects/bedtime-buddy]] — Uses memory mode in production
- [[Claude/Workspace]] — Full project registry

## Notes
- Keep in sync with `~/.claude/` configs when making updates
- Also mirrored at `~/.claude/memory-mode-portable/`
- README.md is the public-facing documentation

## Recent Activity
```dataview
TABLE type, date
FROM [[]]
SORT date DESC
LIMIT 10
```
```

### 4.5 Progress Note

**Location**: `Progress/{project-name}.md`
**Replaces**: `progress/active.md` + `progress/completed.md`

One progress note per project. Long-lived, continuously updated.

```markdown
---
type: progress
project: "[[Claude/Projects/memory-mode-portable]]"
updated: 2026-04-05
tags:
  - progress
---

# memory-mode-portable — Progress

## Current Focus
v2.0 Obsidian backend integration

## Active Work
- [ ] Complete OBSIDIAN-DESIGN.md
- [ ] Implement memory-config.json support
- [ ] Update install.sh for backend selection
- [ ] Create Obsidian templates
- [ ] Update hooks for vault path awareness
- [ ] Write migration script
- [ ] Update MEMORY.md instructions
- [ ] Test end-to-end with real vault

## Completed
- [x] v1.6.0 Auto-save hooks (2026-04-04)
- [x] v1.5.1 Review fixes (2026-04-03)
- [x] v1.5.0 User-level installation
- [x] v1.4.0 Auto-activation
- [x] v1.3.1 Branch tracking

## Upcoming / Backlog
- Canvas view integration (v2.1?)
- Daily notes integration (v2.1?)
- Obsidian plugin for Claude session management (v3.0?)
```

### 4.6 Resource Note

**Location**: `Resources/References/{descriptive title}.md` (for written notes)
**Or**: `Resources/{category}/{filename}` (for binary files, with companion note)

```markdown
---
type: resource
category: reference
source: user-shared
date: 2026-04-05
tags:
  - resource
  - source/user-shared
  - api
  - authentication
related:
  - "[[Claude/Projects/bedtime-buddy]]"
---

# API Specification v2

Shared by Blue on 2026-04-05 for reference during auth endpoint redesign.

## Summary
OpenAPI 3.0 spec for the bedtime-buddy REST API. Covers authentication,
story generation, and subscription management endpoints.

## Key Sections
- **Authentication** (pages 1-5): JWT flow, refresh tokens, OAuth providers
- **Story API** (pages 6-15): Generation, history, favorites
- **Subscriptions** (pages 16-20): Stripe integration, plan management

## File
Raw file: [[Claude/Resources/PDFs/bedtime-buddy-api-spec-v2.pdf]]

## Related
- [[Claude/Projects/bedtime-buddy]]
- [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]]
- [[Claude/Analysis/AuthService deep dive]]
```

### 4.7 Person Note

**Location**: `People/{name}.md`
**Replaces**: `~/.claude/user/profile.md`

```markdown
---
type: person
role: Principal Software Engineer
company: KorTerra
team: Mobile Applications
experience: Principal/Staff
tags:
  - person
---

# Blue Williams

## Identity
- **Role**: Principal Software Engineer
- **Company**: KorTerra
- **Team**: Mobile Applications
- **Experience**: Principal/Staff level

## Background
Deep engineering experience, currently focused on mobile application
development. Strong advocate for AI-augmented workflows and actively
exploring how to make AI collaboration more effective and natural.

## Working Style
Values organic learning over formal onboarding. Prefers to let understanding
develop naturally through collaboration rather than structured Q&A sessions.

Biggest frustration: the short-term memory problem in AI assistants. Wants
genuine continuity across sessions — to build rapport and pick up where
things left off, not start fresh every time.

## What Matters
- Relationship continuity over transactional help
- Context that persists and compounds over time
- Working together as a team, not just tool usage

## Family
- Partner: Nicole
- Son: Elijah (6 years old)
- Younger son
- Cat

## Projects
- [[Claude/Projects/memory-mode-portable]] — Creator/maintainer
- [[Claude/Projects/bedtime-buddy]] — Creator
```

### 4.8 Preferences Note

**Location**: `People/_Preferences.md`
**Replaces**: `~/.claude/user/preferences.md`

```markdown
---
type: preferences
updated: 2026-04-05
tags:
  - preferences
  - meta
---

# Working Preferences

## Communication
- **Detail Level**: Balanced
- **Explanation Style**: Explain then code
- **Feedback Style**: Direct

## Code Preferences
- **Comments**: Moderate
- **Naming**: Descriptive
- **Error Handling**: Fail-fast

## Workflow
- **Planning**: Light plan
- **Review**: Show diffs
- **Testing**: Automated

## Tool Preferences
- **Thinking Depth**: Standard
- **Compression**: Auto

## Observations

### 2026-01-20: Values relationship continuity
**Confidence**: High
**Confirmed**: Yes
**Pattern**: Blue consistently prioritizes rapport and ongoing context over
transactional interactions. Frame all work as continuing a collaboration,
not starting fresh.

### 2026-04-05: Thinks in knowledge graphs
**Confidence**: Medium
**Confirmed**: Pending
**Pattern**: The Obsidian idea suggests Blue naturally thinks in terms of
connected knowledge, not isolated files. Design for discoverability and
relationships.
```

### 4.9 Sub-Agent Output Note

**Location**: `Sub-Agents/{date} {HHMMSS} {task-name}.md`
**Replaces**: `subagent/YYYY-MM-DD_HHMMSS_taskname_XXXX.md`

```markdown
---
type: subagent
project: "[[Claude/Projects/bedtime-buddy]]"
date: 2026-01-19T22:30:00Z
agent: Explore
task: Security scan of auth module
tags:
  - subagent
  - security
---

# Security Scan: Auth Module

## Summary
Scanned all authentication-related files in bedtime-buddy. Found 3 issues
of varying severity. The most critical is XSS vulnerability from localStorage
token storage.

## Details
Examined 12 files across `src/services/`, `src/middleware/`, and `src/routes/`.
[Full findings...]

## Files Analyzed
- `src/services/AuthService.ts`
- `src/middleware/auth.middleware.ts`
- `src/routes/auth.routes.ts`
- [...]

## Recommendations
- Immediate: Migrate token storage to httpOnly cookies
- Short-term: Add CSRF middleware
- Medium-term: Implement token refresh mutex

## Related
- [[Claude/Analysis/AuthService deep dive]]
- [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]]
```

### 4.10 Workspace Note

**Location**: `Workspace.md` (vault root)
**Replaces**: `~/.claude/workspace.md`

```markdown
---
type: workspace
updated: 2026-04-05
tags:
  - meta
  - workspace
---

# Workspace

## Project Registry

| Project | Status | Stack | Role |
|---------|--------|-------|------|
| [[Claude/Projects/memory-mode-portable]] | Active | Bash, Markdown | Creator |
| [[Claude/Projects/bedtime-buddy]] | Active | React, Express, Stripe | Creator |

## Relationships
- [[Claude/Projects/bedtime-buddy]] uses [[Claude/Projects/memory-mode-portable]] for session persistence

## Current Initiatives

### v2.0 Obsidian Backend
- **Status**: In Design
- **Projects**: [[Claude/Projects/memory-mode-portable]]
- **Target**: April 2026
```

### 4.11 Daily Note (Optional)

**Location**: `Daily/{date}.md`

If the user enables daily notes, Claude appends to the daily note as a lightweight log. This is *not* a replacement for session notes — it's a timeline view.

```markdown
---
type: daily
date: 2026-04-05
tags:
  - daily
---

# 2026-04-05

## Sessions
- [[Claude/Sessions/2026-04-05 memory-mode-portable]] — Designed Obsidian backend

## Decisions Made
- [[Claude/Decisions/2026-04-05 Use Obsidian as memory backend]]

## Resources Added
- (none today)

## Notes
Productive design session. Blue excited about knowledge graph approach.
```

---

## 5. Tag Taxonomy

Tags are hierarchical using Obsidian's nested tag syntax (`#parent/child`). Every note gets at minimum a **type tag**.

### Type Tags (required — one per note)

| Tag | Used On | Purpose |
|-----|---------|---------|
| `#decision` | Decision notes | Architectural/implementation choices |
| `#analysis` | Analysis notes | Code/component deep dives |
| `#session` | Session logs | What Claude is working on right now |
| `#progress` | Progress notes | Sprint/work tracking |
| `#project` | Project notes | Project overviews |
| `#resource` | Resource notes | User-shared files and references |
| `#person` | People notes | Team members, user profile |
| `#subagent` | Sub-agent outputs | Delegated task results |
| `#preferences` | Preferences note | Working style preferences |
| `#workspace` | Workspace note | Cross-project map |
| `#daily` | Daily notes | Timeline view |
| `#meta` | System notes | Dashboard, templates, config |

### Domain Tags (contextual — zero or more per note)

```
#architecture        #security          #performance
#frontend            #backend           #devops
#testing             #documentation     #ai-tools
#authentication      #database          #api
#mobile              #deployment        #monitoring
#accessibility       #design-system     #state-management
```

### Status Tags (for filtering active/completed work)

```
#status/active       #status/completed  #status/blocked
#status/superseded   #status/archived   #status/pending
```

### Decision Category Tags

```
#category/architecture    #category/implementation
#category/configuration   #category/dependency
#category/process
```

### Source Tags (for resources)

```
#source/user-shared      #source/web
#source/generated        #source/meeting
#source/session          #source/documentation
```

### Severity Tags (for analysis findings)

```
#severity/critical    #severity/high
#severity/medium      #severity/low
```

### Tag Rules for Claude

1. **Always apply the type tag** — every note gets exactly one type tag
2. **Always tag the project** — use the `project` frontmatter field with a wikilink, not a tag (avoids tag explosion)
3. **Apply 2-5 domain tags** — enough to be findable, not so many they're meaningless
4. **Status tags go in frontmatter** — use the `status` field, not inline tags, for machine queryability
5. **Don't invent new tags** — use the taxonomy above. If a new tag is genuinely needed, add it to this document first

---

## 6. Linking Strategy & Graph Design

### The Graph Mental Model

```
                    ┌──────────┐
                    │Workspace │
                    └────┬─────┘
                         │ links to
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         ┌─────────┐ ┌─────────┐ ┌─────────┐
         │Project A│ │Project B│ │Project C│   ← Hub nodes
         └────┬────┘ └────┬────┘ └─────────┘
              │           │
     ┌────────┼────┐    ┌─┼──────────┐
     ▼        ▼    ▼    ▼ ▼          ▼
  Decision  Session Analysis  Decision Session
     │                  │        │
     └──────────────────┘        │
            shared                │
           analysis    ──────────┘
                      cross-project
                        link!

  Resources ←──── linked from any note
  People    ←──── linked from projects, sessions
```

**Projects are hubs**. Every note links back to its project. The graph naturally forms a star topology per project, with cross-project links creating bridges.

### Wikilink Conventions

| From | To | Link Format | Purpose |
|------|----|-------------|---------|
| Any note | Its project | `[[Claude/Projects/project-name]]` | Project hub connection |
| Decision | Related decisions | `[[Claude/Decisions/date title]]` | Decision chains |
| Decision | Triggering analysis | `[[Claude/Analysis/title]]` | Evidence trail |
| Session | Decisions made | `[[Claude/Decisions/date title]]` | Session history |
| Session | Current progress | `[[Claude/Progress/project-name]]` | Work tracking |
| Analysis | Related decisions | `[[Claude/Decisions/date title]]` | Recommendations → actions |
| Resource | Related projects | `[[Claude/Projects/project-name]]` | Context |
| Resource | Related notes | `[[Claude/Decisions/...]]`, `[[Claude/Analysis/...]]` | Usage context |
| Project | Related projects | `[[Claude/Projects/other-project]]` | Dependencies |
| Daily | Sessions that day | `[[Claude/Sessions/date project]]` | Timeline |

### Frontmatter `project` Field

Every note (except Workspace, People, Preferences, Dashboard) has a `project` field in frontmatter:

```yaml
project: "[[Claude/Projects/memory-mode-portable]]"
```

This creates a **backlink** in Obsidian — when viewing the project note, all related notes appear in the backlinks panel. It also enables Dataview queries like:

```dataview
TABLE type, date FROM "" WHERE project = [[Claude/Projects/memory-mode-portable]]
```

### Aliases for Flexible Linking

Project notes should include aliases so links work naturally:

```yaml
aliases:
  - memory mode
  - infinite memory
  - memory-mode-portable
```

This means `[[memory mode]]` resolves to the same note as `[[Claude/Projects/memory-mode-portable]]`.

### Avoiding Orphan Notes

Claude must follow these rules:
1. **Every note links to at least one other note** (minimum: its project)
2. **Every decision links to what triggered it** (session, analysis, or another decision)
3. **Every resource links to why it matters** (project, decision, or analysis)
4. **Session notes link to everything created during that session**

### Cross-Project Links

When a decision or analysis in one project is relevant to another:

```markdown
## Related
- [[Claude/Projects/bedtime-buddy]] — This auth pattern could apply there too
- [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]] — Similar problem space
```

These cross-project links are what make the graph view genuinely useful — they surface connections the user might not have noticed.

---

## 7. Obsidian Templates

Shipped in `_Templates/` folder. User configures Obsidian's Templates core plugin to use this folder.

### Decision Template

**File**: `_Templates/Decision.md`

```markdown
---
type: decision
project: "[[Claude/Projects/]]"
date: {{date}}
status: pending
category: 
tags:
  - decision
aliases: []
---

# {{title}}

## Context
Why this decision is needed.

## Decision
What was decided.

## Alternatives Considered
- **Option A**: Description, tradeoffs
- **Option B**: Description, tradeoffs

## Consequences
- Impact on architecture
- Impact on timeline
- Impact on other systems

## Related
- [[Projects/]]
```

### Analysis Template

**File**: `_Templates/Analysis.md`

```markdown
---
type: analysis
project: "[[Claude/Projects/]]"
date: {{date}}
path: 
component: 
tags:
  - analysis
---

# Analysis: {{title}}

## Summary
2-3 sentence overview.

## Key Findings
- Finding 1
- Finding 2

## Issues Found

| Severity | Issue | Location |
|----------|-------|----------|
|          |       |          |

## Recommendations
- Recommendation 1
- Recommendation 2

## Related
- [[Projects/]]
```

### Session Log Template

**File**: `_Templates/Session Log.md`

```markdown
---
type: session
project: "[[Claude/Projects/]]"
date: {{date}}
branch: 
status: active
tags:
  - session
---

# Session: {{title}} ({{date}})

## Current Task
What we're working on.

## Progress
- [ ] Step 1
- [ ] Step 2

## Blockers
None.

## Decisions Made
- (none yet)

## Key Context for Recovery
If reading this after compaction: summarize the essential state here.
```

### Project Template

**File**: `_Templates/Project.md`

```markdown
---
type: project
path: 
repo: 
status: active
stack: []
tags:
  - project
aliases: []
---

# {{title}}

## Overview
What this project is and why it exists.

## Role
Your role on this project.

## Tech Stack
- **Language**: 
- **Framework**: 
- **Database**: 
- **Deployment**: 

## Related Projects
- 

## Notes
Project-specific context.

## Activity
```dataview
TABLE type, date
FROM [[]]
SORT date DESC
LIMIT 10
\```
```

### Progress Template

**File**: `_Templates/Progress.md`

```markdown
---
type: progress
project: "[[Claude/Projects/]]"
updated: {{date}}
tags:
  - progress
---

# {{title}} — Progress

## Current Focus
What the current sprint/initiative is.

## Active Work
- [ ] Task 1
- [ ] Task 2

## Completed
- [x] Done item (date)

## Upcoming
- [ ] Future item
```

### Resource Template

**File**: `_Templates/Resource.md`

```markdown
---
type: resource
category: 
source: user-shared
date: {{date}}
tags:
  - resource
related: []
---

# {{title}}

## Summary
What this resource is and why it's here.

## Key Points
- Point 1
- Point 2

## File
Link to raw file if applicable: [[Claude/Resources/]]

## Related
- [[Projects/]]
```

### Sub-Agent Output Template

**File**: `_Templates/Sub-Agent Output.md`

```markdown
---
type: subagent
project: "[[Claude/Projects/]]"
date: {{date}}
agent: 
task: 
tags:
  - subagent
---

# {{title}}

## Summary
2-3 sentence overview.

## Details
Full findings.

## Files Analyzed
- file1
- file2

## Recommendations
- Recommendation 1

## Related
- [[Projects/]]
```

---

## 8. Dataview Queries & Dashboards

### Main Dashboard

**File**: `_Dashboard.md`

```markdown
---
type: meta
tags:
  - meta
  - dashboard
aliases:
  - Home
  - Dashboard
---

# Claude Mind — Dashboard

> Your AI-powered knowledge base. Browse, search, and discover.

---

## Active Projects

```dataview
TABLE WITHOUT ID
  file.link AS "Project",
  status AS "Status",
  stack AS "Stack"
FROM #project
WHERE status = "active"
SORT file.name ASC
\```

---

## Active Sessions

```dataview
TABLE WITHOUT ID
  file.link AS "Session",
  project AS "Project",
  branch AS "Branch"
FROM #session
WHERE status = "active"
SORT date DESC
\```

---

## Recent Decisions

```dataview
TABLE WITHOUT ID
  file.link AS "Decision",
  project AS "Project",
  status AS "Status",
  category AS "Category"
FROM #decision
SORT date DESC
LIMIT 15
\```

---

## Recent Analysis

```dataview
TABLE WITHOUT ID
  file.link AS "Analysis",
  project AS "Project",
  component AS "Component"
FROM #analysis
SORT date DESC
LIMIT 10
\```

---

## Recent Resources

```dataview
TABLE WITHOUT ID
  file.link AS "Resource",
  category AS "Category",
  source AS "Source"
FROM #resource
SORT date DESC
LIMIT 10
\```

---

## Current Blockers

```dataview
LIST
FROM #session
WHERE status = "active" AND contains(file.content, "## Blockers") AND !contains(file.content, "Blockers\nNone")
\```

---

## Sub-Agent Activity

```dataview
TABLE WITHOUT ID
  file.link AS "Output",
  project AS "Project",
  agent AS "Agent",
  task AS "Task"
FROM #subagent
SORT date DESC
LIMIT 10
\```

---

## Stats

- **Total Projects**: `$= dv.pages('#project').length`
- **Total Decisions**: `$= dv.pages('#decision').length`
- **Total Analyses**: `$= dv.pages('#analysis').length`
- **Total Resources**: `$= dv.pages('#resource').length`
- **Total Sessions**: `$= dv.pages('#session').length`
```

### Per-Project Query (embedded in Project notes)

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  type AS "Type",
  date AS "Date"
FROM ""
WHERE contains(string(project), this.file.name)
SORT date DESC
LIMIT 15
```

### Decision Timeline Query

Useful as a standalone note or embedded anywhere:

```dataview
TABLE WITHOUT ID
  file.link AS "Decision",
  project AS "Project",
  category AS "Category",
  status AS "Status"
FROM #decision
SORT date DESC
```

### Resource Browser Query

```dataview
TABLE WITHOUT ID
  file.link AS "Resource",
  category AS "Category",
  source AS "Source",
  related AS "Related To"
FROM #resource
GROUP BY category
SORT date DESC
```

---

## 9. Shared Resources System

This is a key differentiator from v1.x. The vault is a **shared workspace** where both the user and Claude can contribute content.

### How It Works

#### User Shares a File During a Session

1. **User drops file**: Into `Resources/PDFs/`, `Resources/Images/`, etc.
2. **User tells Claude**: "I added the API spec to Resources/PDFs/"
3. **Claude reads it**: Uses Read tool to access the file
4. **Claude creates a companion note**: A Resource note in `Resources/References/` with:
   - Summary of the file's contents
   - Key points extracted
   - Link to the raw file
   - Wikilinks to relevant projects/decisions
   - Appropriate tags
5. **Claude links it**: Updates relevant session/project notes with a wikilink to the resource

#### User Shares a File in Chat

1. **User pastes content or references a file** during conversation
2. **Claude evaluates**: Is this worth persisting in the vault?
3. **If yes**: Claude saves to appropriate Resources subfolder + creates companion note
4. **Claude announces**: "Saved to vault: [[Claude/Resources/References/API spec v2]]"
5. **Linked**: Into the current session note and relevant project

#### User Writes Their Own Notes

Users can create notes anywhere in the vault using normal Obsidian. If they follow the tag/frontmatter conventions, Claude will discover and link to them naturally. If they don't, Claude can still find them via search.

**Claude's discovery protocol for user-created notes**:
1. On session start, scan for new notes without a `type` frontmatter field (user-created)
2. If relevant to the current project, mention them: "I noticed you added a note about X"
3. Offer to add frontmatter/tags if the user wants it indexed

### Resource Categories

| Folder | Contents | Companion Note Location |
|--------|----------|------------------------|
| `Resources/PDFs/` | PDF documents | `Resources/References/` |
| `Resources/Images/` | Screenshots, diagrams, photos | `Resources/References/` |
| `Resources/Documents/` | Word docs, spreadsheets, exports | `Resources/References/` |
| `Resources/Snippets/` | Code snippets, config examples | `Resources/References/` |
| `Resources/References/` | Written reference notes (no raw file) | (self-contained) |
| `Resources/Meeting Notes/` | Meeting transcripts, agendas | `Resources/References/` |

### Resource Index MOC

**File**: `Resources/_Resource Index.md`

Auto-maintained map of content for the Resources folder:

```markdown
---
type: meta
tags:
  - meta
  - resources
---

# Resource Index

## By Category

### PDFs
```dataview
LIST FROM #resource WHERE category = "pdf" SORT date DESC
\```

### Images
```dataview
LIST FROM #resource WHERE category = "image" SORT date DESC
\```

### Code Snippets
```dataview
LIST FROM #resource WHERE category = "snippet" SORT date DESC
\```

### References
```dataview
LIST FROM #resource WHERE category = "reference" SORT date DESC
\```

### Meeting Notes
```dataview
LIST FROM #resource WHERE category = "meeting" SORT date DESC
\```

## By Source

### User Shared
```dataview
LIST FROM #resource WHERE source = "user-shared" SORT date DESC
\```

### From Sessions
```dataview
LIST FROM #resource WHERE source = "session" SORT date DESC
\```
```

---

## 10. Session & State Management

### Machine State vs. Human Notes

The Obsidian backend splits state into two layers:

| Layer | Format | Location | Purpose |
|-------|--------|----------|---------|
| **Machine state** | JSON | `.claude-state/{project-key}/` | Auto-activation, hooks, stats |
| **Human notes** | Markdown | `Sessions/`, `Progress/`, etc. | Knowledge base, graph, reading |

### session.json (Machine State)

**Location**: `{vault}/.claude-state/{project-key}/session.json`

Identical schema to v1.x `_session.json`:

```json
{
  "active": true,
  "autoActivate": true,
  "started": "2026-04-05T10:00:00Z",
  "projectKey": "memory-mode-portable",
  "projectPath": "/Users/blue/workspace/memory-mode-portable",
  "branch": "main",
  "lastActivity": "2026-04-05T14:30:00Z",
  "stats": {
    "decisions": 3,
    "analyses": 1,
    "sessions": 5,
    "resources": 2,
    "subagentOutputs": 1
  }
}
```

### recent.md (Quick Recovery Index)

**Location**: `{vault}/.claude-state/{project-key}/recent.md`

Lightweight index for fast compaction recovery. Similar to v1.x `_index.md` but pointing to vault notes:

```markdown
# Recent: memory-mode-portable
Updated: 2026-04-05T14:30:00Z
Status: ACTIVE
Branch: main

## Current
- Task: Designing Obsidian backend → Sessions/2026-04-05 memory-mode-portable.md
- Progress: v2.0 design phase → Progress/memory-mode-portable.md
- Blockers: None

## Recent Notes
| Type | File | Updated | Summary |
|------|------|---------|---------|
| Session | Sessions/2026-04-05 memory-mode-portable.md | 14:30 | Obsidian design |
| Decision | Decisions/2026-04-05 Use Obsidian as memory backend.md | 11:00 | Approved |
| Progress | Progress/memory-mode-portable.md | 14:30 | v2.0 active work |
```

### Auto-Activation Flow (Obsidian Backend)

```
Session Start
    │
    ▼
Read ~/.claude/memory-config.json
    │
    ├── backend = "default" → (v1.x behavior, unchanged)
    │
    └── backend = "obsidian" → Read vaultPath
            │
            ▼
        Derive project key from cwd
            │
            ▼
        Check {vault}/.claude-state/{project-key}/session.json
            │
            ├── Not found → Normal mode (user runs /memory start)
            │
            └── Found + autoActivate = true
                    │
                    ▼
                Set active: true, update timestamps
                Read {vault}/.claude-state/{project-key}/recent.md
                Read People/_Preferences.md
                Read Projects/{project-name}.md (if exists)
                    │
                    ▼
                Memory mode active. Resume.
```

### Breadcrumb System (Unchanged Concept)

Same breadcrumb protocol, just referencing vault paths:

```
<!-- MEMORY_BREADCRUMB: memory-mode-portable 2026-04-05T14:30:00Z obsidian -->
```

The `obsidian` suffix tells recovery logic which backend to use.

### /memory start (Obsidian Backend)

1. Derive project key from cwd
2. Read `~/.claude/memory-config.json` → get vault path
3. Create `.claude-state/{project-key}/` in vault
4. Create `session.json` and `recent.md`
5. Create `Projects/{project-name}.md` if not exists
6. Create `Progress/{project-name}.md` if not exists
7. Create first session note: `Sessions/{date} {project-name}.md`
8. Update `Workspace.md` with new project entry
9. Confirm: "Memory mode active for {project-key}. Vault: {vaultPath}"

---

## 11. Hook System Updates

### Backend-Aware Hooks

All three hooks need to read the backend config to determine paths.

#### Common Helper (new file: `memory-common.sh`)

```bash
#!/bin/bash
# memory-common.sh — Shared utilities for memory hooks
# Determines active backend and resolves paths.

CONFIG_FILE="$HOME/.claude/memory-config.json"

get_backend() {
    if [ -f "$CONFIG_FILE" ] && jq -e '.backend' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq -r '.backend' "$CONFIG_FILE" 2>/dev/null
    else
        echo "default"
    fi
}

get_vault_path() {
    if [ -f "$CONFIG_FILE" ]; then
        local raw
        raw=$(jq -r '.obsidian.vaultPath // empty' "$CONFIG_FILE" 2>/dev/null) || true
        # Expand ~ to $HOME
        echo "${raw/#\~/$HOME}"
    fi
}

get_state_dir() {
    local backend
    backend=$(get_backend)
    if [ "$backend" = "obsidian" ]; then
        local vault
        vault=$(get_vault_path)
        echo "$vault/.claude-state"
    else
        echo "$HOME/.claude/.memory-hooks"
    fi
}
```

#### memory-tracker.sh Changes

```diff
+ # Source common utilities
+ SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+ source "$SCRIPT_DIR/memory-common.sh" 2>/dev/null || true
+
- STATE_DIR="$HOME/.claude/.memory-hooks"
+ STATE_DIR=$(get_state_dir 2>/dev/null) || STATE_DIR="$HOME/.claude/.memory-hooks"
  STATE_FILE="$STATE_DIR/activity.json"
  # ... rest unchanged
```

#### memory-nudge.sh Changes

The nudge message changes based on backend:

```bash
BACKEND=$(get_backend 2>/dev/null) || BACKEND="default"

if [ "$BACKEND" = "obsidian" ]; then
    VAULT=$(get_vault_path 2>/dev/null) || VAULT=""
    NUDGE="<memory-checkpoint reason=\"post-commit\" backend=\"obsidian\" vault=\"$VAULT\">..."
    # Message references: "Update the session note in Sessions/ and Progress/ in your vault"
else
    NUDGE="<memory-checkpoint reason=\"post-commit\" backend=\"default\">..."
    # Message references: "Update context/current-task.md and progress/active.md"
fi
```

#### memory-precompact.sh Changes

Same pattern — backend-aware messaging:

```bash
if [ "$BACKEND" = "obsidian" ]; then
    echo "<memory-checkpoint reason=\"pre-compaction\" priority=\"critical\" backend=\"obsidian\" vault=\"$VAULT\">Context compaction imminent. Save ALL state to your Obsidian vault NOW: update the active session note in Sessions/, progress in Progress/, and any unsaved decisions to Decisions/. You have $EDITS unsaved edits across $FILES_COUNT files.</memory-checkpoint>"
else
    echo "<memory-checkpoint reason=\"pre-compaction\" priority=\"critical\" backend=\"default\">..."
fi
```

### install-hooks.sh Changes

```diff
+ # Also install memory-common.sh
+ cp "$SCRIPT_DIR/memory-common.sh" "$HOOKS_DIR/memory-common.sh"
+ chmod +x "$HOOKS_DIR/memory-common.sh"
```

---

## 12. Installer Updates

### install.sh — New Interactive Flow

```
=== Infinite Memory Mode Installer ===

Choose storage backend:
  1) Default   — Files stored at ~/.claude/projects/ (current behavior)
  2) Obsidian  — Files stored in an Obsidian vault (knowledge base)

Your choice [1/2]: 2

Obsidian vault path
  Enter path (or press Enter for ~/Obsidian/ClaudeMind): ~/Obsidian/ClaudeMind

  Creating vault at ~/Obsidian/ClaudeMind...
  ✓ Vault directory created
  ✓ .claude-state/ directory created
  ✓ Templates installed to _Templates/
  ✓ Dashboard created at _Dashboard.md
  ✓ Workspace note created
  ✓ Folder structure created (Projects/, Decisions/, Analysis/, etc.)

  NOTE: Open this folder in Obsidian as a vault.
  Recommended plugins: Dataview, Templates (core plugin)

Installing core instruction files...
  ✓ MEMORY.md updated
  ✓ USER.md updated
  ✓ memory-config.json created (backend: obsidian)

=== Installation Complete ===

Next steps:
  1. Open ~/Obsidian/ClaudeMind in Obsidian
  2. Enable core plugin: Templates (set folder to _Templates)
  3. Install community plugin: Dataview
  4. Edit People/Your Name.md with your info
  5. Install auto-save hooks: ./hooks/install-hooks.sh
  6. Open any project and run: /memory start
```

### What Gets Created (Obsidian Backend)

```bash
# Vault structure
mkdir -p "$VAULT_PATH"/{.claude-state,_Templates,Projects,Decisions,Analysis}
mkdir -p "$VAULT_PATH"/{Sessions,Progress,Resources/{PDFs,Images,Documents,Snippets,References,"Meeting Notes"}}
mkdir -p "$VAULT_PATH"/{People,Sub-Agents,Daily}

# Template files (copied from repo's obsidian-templates/ directory)
cp obsidian-templates/*.md "$VAULT_PATH/_Templates/"

# Dashboard
cp obsidian-templates/_Dashboard.md "$VAULT_PATH/_Dashboard.md"

# Workspace note
cp obsidian-templates/Workspace.md "$VAULT_PATH/Workspace.md"

# Resource index
cp obsidian-templates/_Resource\ Index.md "$VAULT_PATH/Resources/_Resource Index.md"

# Default person note
cp obsidian-templates/Person.md "$VAULT_PATH/People/Your Name.md"

# Default preferences
cp obsidian-templates/_Preferences.md "$VAULT_PATH/People/_Preferences.md"

# Config
cat > "$HOME/.claude/memory-config.json" << EOF
{
  "version": "2.0.0",
  "backend": "obsidian",
  "obsidian": {
    "vaultPath": "$VAULT_PATH",
    "features": {
      "dataview": true,
      "templates": true
    }
  },
  "default": {
    "basePath": "$HOME/.claude/projects"
  }
}
EOF
```

---

## 13. MEMORY.md Instruction Updates

MEMORY.md needs a new section that teaches Claude the Obsidian workflow. The section activates based on the backend config.

### Key Additions

```markdown
## Obsidian Backend (v2.0+)

When `~/.claude/memory-config.json` has `"backend": "obsidian"`, use the
Obsidian vault as the storage backend instead of `~/.claude/projects/`.

### Reading the Config

On session start:
1. Read `~/.claude/memory-config.json`
2. If `backend` = `"obsidian"`, resolve `obsidian.vaultPath` (expand `~`)
3. All memory operations target the vault path
4. Machine state lives in `{vault}/.claude-state/`
5. Human-readable notes live in vault root folders

### Writing Obsidian Notes

Every note MUST have:
1. **YAML frontmatter** with `type`, `project`, `date`, and `tags` fields
2. **At least one wikilink** to another note (minimum: the project note)
3. **A descriptive title** as the H1 heading (human-readable, not coded)
4. **Appropriate tags** from the tag taxonomy

### Note Locations

| Note Type | Folder | Naming Pattern |
|-----------|--------|----------------|
| Decision | `Decisions/` | `{date} {descriptive title}.md` |
| Analysis | `Analysis/` | `{descriptive title}.md` |
| Session | `Sessions/` | `{date} {project-name}.md` |
| Progress | `Progress/` | `{project-name}.md` |
| Resource | `Resources/References/` | `{descriptive title}.md` |
| Sub-Agent | `Sub-Agents/` | `{date} {HHMMSS} {task-name}.md` |

### Creating Wikilinks

- Link to projects: `[[Claude/Projects/project-name]]`
- Link to decisions: `[[Claude/Decisions/2026-04-05 Decision title]]`
- Link to analyses: `[[Claude/Analysis/Component name deep dive]]`
- Link to resources: `[[Claude/Resources/References/Resource title]]`
- Link to sessions: `[[Claude/Sessions/2026-04-05 project-name]]`

### Handling Shared Resources

When the user shares a file or tells you about a file they've added:
1. Read the file from `Resources/` if possible
2. Create a companion Resource note in `Resources/References/`
3. Include a summary, key points, and a link to the raw file
4. Link the resource to relevant project/decision/analysis notes
5. Update the current session note with a reference

### Compaction Recovery (Obsidian)

After detecting missing breadcrumb:
1. Read `{vault}/.claude-state/{project-key}/recent.md`
2. Read `People/_Preferences.md`
3. Read the active session note referenced in recent.md
4. Read the project note if deeper context needed
5. Resume with full context
```

---

## 14. Sub-Agent Protocol Updates

### Obsidian-Aware Sub-Agent Prompt Template

```
[Your task description here]

MEMORY SYSTEM INSTRUCTIONS (Obsidian Backend):
This project uses an Obsidian vault for memory at {vault-path}

1. CONTEXT: Read {vault}/.claude-state/{project-key}/recent.md for quick context
2. CONTEXT: Read {vault}/Projects/{project-name}.md for project overview
3. OUTPUT: Write findings to {vault}/Sub-Agents/{date} {HHMMSS} {task-name}.md
4. FORMAT: Use Obsidian note format with YAML frontmatter, tags, and wikilinks
5. LINKING: Include [[Projects/{project-name}]] link and relevant wikilinks
6. RESTRICTION: Do NOT modify .claude-state/ files — parent agent handles those

Required frontmatter:
---
type: subagent
project: "[[Projects/{project-name}]]"
date: {ISO timestamp}
agent: {agent type}
task: {brief description}
tags:
  - subagent
  - {domain tags}
---
```

### Parent Consolidation (Obsidian)

After sub-agent completes:
1. Read its output from `Sub-Agents/`
2. If findings are significant, create proper Decision or Analysis notes
3. Link the sub-agent output from the session note
4. Update `recent.md` with new entries
5. Increment stats in `session.json`

---

## 15. Migration from v1.x

### migrate-to-obsidian.sh

New script for converting existing memory to Obsidian format.

```bash
#!/bin/bash
# migrate-to-obsidian.sh — Migrate v1.x memory files to Obsidian vault
#
# Usage: ./migrate-to-obsidian.sh [vault-path]
# If vault-path omitted, reads from memory-config.json

set -e
```

### Migration Steps

```
1. READ existing state
   ├── ~/.claude/projects/*/              (all project directories)
   ├── ~/.claude/user/                    (user profile)
   └── ~/.claude/workspace.md             (workspace map)

2. CREATE vault structure
   ├── All folders from Section 3
   ├── Templates from Section 7
   └── Dashboard from Section 8

3. CONVERT per-project files
   For each project in ~/.claude/projects/{key}/:
   │
   ├── project.md
   │   → Projects/{project-name}.md
   │   + Add YAML frontmatter (type, path, repo, status, stack, tags)
   │   + Add aliases
   │   + Add Dataview query for related notes
   │   + Convert any plain references to [[wikilinks]]
   │
   ├── decisions/YYYY-MM-DD_NNN_description.md
   │   → Decisions/YYYY-MM-DD {Readable Title}.md
   │   + Add YAML frontmatter (type, project wikilink, date, status, category, tags)
   │   + Convert "## Related" items to [[wikilinks]]
   │   + Infer tags from content (security, architecture, etc.)
   │
   ├── analysis/path_to_file.md
   │   → Analysis/{Readable Component Name}.md
   │   + Add YAML frontmatter (type, project wikilink, date, path, component, tags)
   │   + Convert references to [[wikilinks]]
   │
   ├── context/current-task.md
   │   → Sessions/YYYY-MM-DD {project-name}.md
   │   + Add YAML frontmatter (type, project wikilink, date, branch, status, tags)
   │   + Merge blockers.md content into Blockers section
   │
   ├── progress/active.md + completed.md
   │   → Progress/{project-name}.md
   │   + Add YAML frontmatter (type, project wikilink, updated, tags)
   │   + Merge active and completed into single note
   │
   ├── subagent/*.md
   │   → Sub-Agents/{date} {time} {task-name}.md
   │   + Add YAML frontmatter (type, project wikilink, date, agent, task, tags)
   │
   ├── _session.json
   │   → .claude-state/{project-key}/session.json (copy + update paths)
   │
   └── _index.md + _index-archive.md
       → .claude-state/{project-key}/recent.md (regenerated from new files)

4. CONVERT global files
   │
   ├── ~/.claude/user/profile.md
   │   → People/{user-name}.md
   │   + Convert to Person note format with frontmatter
   │
   ├── ~/.claude/user/preferences.md
   │   → People/_Preferences.md
   │   + Convert to Preferences note format with frontmatter
   │   + Merge observations.md and feedback.md content
   │
   └── ~/.claude/workspace.md
       → Workspace.md
       + Add YAML frontmatter
       + Convert project references to [[wikilinks]]

5. GENERATE new files
   ├── _Dashboard.md (with Dataview queries)
   ├── Resources/_Resource Index.md
   └── _Templates/*.md

6. UPDATE config
   └── ~/.claude/memory-config.json → set backend: "obsidian"

7. VERIFY
   ├── Count notes created vs files migrated
   ├── Check for orphan notes (no links)
   ├── Validate all frontmatter
   └── Report summary

8. BACKUP
   └── ~/.claude/projects/ preserved (not deleted)
       User can remove manually after verifying migration
```

### Migration Report

```
=== Migration Complete ===

Migrated from: ~/.claude/projects/
Migrated to:   ~/Obsidian/ClaudeMind/

Projects:     3 migrated
Decisions:    12 converted
Analyses:     5 converted
Sessions:     8 created
Progress:     3 created
Sub-agents:   4 converted
Resources:    0 (none existed)

Vault stats:
  Total notes: 38
  Wikilinks created: 94
  Tags applied: 156
  Orphan notes: 0

Original files preserved at ~/.claude/projects/
Backend updated to: obsidian

Next: Open ~/Obsidian/ClaudeMind in Obsidian to verify.
```

---

## 16. Recommended Obsidian Plugins

### Required

| Plugin | Type | Why |
|--------|------|-----|
| **Templates** | Core | Enables template insertion for new notes |

### Strongly Recommended

| Plugin | Type | Why |
|--------|------|-----|
| **Dataview** | Community | Powers all dashboard queries and per-project activity views |
| **Graph Analysis** | Community | Enhanced graph view with clustering and filtering |

### Nice to Have

| Plugin | Type | Why |
|--------|------|-----|
| **Calendar** | Community | Visual calendar for daily notes integration |
| **Kanban** | Community | Board view for progress tracking |
| **Excalidraw** | Community | Visual diagrams linked to notes |
| **Omnisearch** | Community | Better full-text search across vault |
| **Tag Wrangler** | Community | Bulk tag management and renaming |

### Obsidian Settings to Configure

```
Settings → Core Plugins:
  ✓ Templates → Template folder: _Templates

Settings → Files & Links:
  ✓ Default location for new notes: In the folder specified below
  ✓ New link format: Relative path to file
  ✓ Use [[Wikilinks]]: ON
  ✓ Automatically update internal links: ON

Settings → Community Plugins → Dataview:
  ✓ Enable JavaScript Queries: ON
  ✓ Enable Inline Queries: ON
```

---

## 17. File Inventory

### New Files to Create (in repo)

```
memory-mode-portable/
├── obsidian-templates/                  # Templates shipped with the project
│   ├── Decision.md
│   ├── Analysis.md
│   ├── Session Log.md
│   ├── Project.md
│   ├── Progress.md
│   ├── Resource.md
│   ├── Sub-Agent Output.md
│   ├── _Dashboard.md
│   ├── _Resource Index.md
│   ├── Workspace.md
│   ├── Person.md
│   └── _Preferences.md
├── hooks/
│   └── memory-common.sh                # NEW: shared backend utilities
├── migrate-to-obsidian.sh              # NEW: migration script
├── memory-config.json.example          # NEW: example config
└── OBSIDIAN-DESIGN.md                  # This document
```

### Modified Files

```
install.sh                  # Backend selection, vault setup
hooks/install-hooks.sh      # Install memory-common.sh
hooks/memory-tracker.sh     # Backend-aware state directory
hooks/memory-nudge.sh       # Backend-aware checkpoint messages
hooks/memory-precompact.sh  # Backend-aware checkpoint messages
MEMORY.md                   # Obsidian backend instructions section
README.md                   # Updated with Obsidian setup guide
```

### Files Unchanged

```
USER.md                     # Concepts unchanged, just storage location differs
CLAUDE.md.example           # Same entry point
workspace.md.example        # Replaced by obsidian-templates/Workspace.md for obsidian backend
.claude/settings.local.json # Unchanged
```

---

## 18. Tiered Retrieval System

The most expensive thing Claude can do is search aimlessly. The tiered retrieval system ensures Claude always starts with the cheapest, most relevant source and only goes deeper when needed. This is the difference between a 2-second context recovery and a 30-second fishing expedition.

### The Three Tiers

```
┌─────────────────────────────────────────────────────┐
│  HOT CACHE (Tier 1)                                 │
│  .claude-state/{project}/recent.md                  │
│  Read: ALWAYS on session start + after compaction   │
│  Contains: Current task, last 10 notes, blockers    │
│  Cost: 1 file read, ~50 lines                       │
│  Answers: "What am I doing? What just happened?"    │
├─────────────────────────────────────────────────────┤
│  WARM CONTEXT (Tier 2)                              │
│  Sessions/{date project}.md + Progress/{project}.md │
│  + Projects/{project}.md                            │
│  Read: When hot cache isn't enough                  │
│  Contains: Full session history, work items, stack  │
│  Cost: 2-3 file reads, ~200 lines                   │
│  Answers: "What's the full picture for this project?"│
├─────────────────────────────────────────────────────┤
│  COLD SEARCH (Tier 3)                               │
│  Full vault — Decisions/, Analysis/, Resources/     │
│  Read: When investigating history or cross-project  │
│  Contains: Everything ever recorded                 │
│  Cost: Multiple reads, glob/grep, tag searches      │
│  Answers: "What did we decide about X last month?"  │
└─────────────────────────────────────────────────────┘
```

### Tier 1: Hot Cache (`recent.md`)

This is the **only file Claude needs to read in 80% of recovery situations**. It's designed to be small, current, and self-contained.

**Location**: `{vault}/.claude-state/{project-key}/recent.md`

**Format**:

```markdown
# Hot Cache: memory-mode-portable
Updated: 2026-04-05T16:45:00Z
Status: ACTIVE
Branch: feature/obsidian-backend

## Right Now
- **Doing**: Writing tiered retrieval section of OBSIDIAN-DESIGN.md
- **Blocked by**: Nothing
- **Next**: Get Blue's review, then start implementation

## Recent Notes (last 10 touched)
| Note | Type | Updated | Why It Matters |
|------|------|---------|----------------|
| Sessions/2026-04-05 memory-mode-portable.md | session | 16:45 | Active session |
| Decisions/2026-04-05 Use Obsidian as memory backend.md | decision | 11:00 | Core v2.0 decision |
| Progress/memory-mode-portable.md | progress | 16:30 | Active work items |
| Projects/memory-mode-portable.md | project | 14:00 | Project overview |

## Quick Links
- Active session → Sessions/2026-04-05 memory-mode-portable.md
- Progress → Progress/memory-mode-portable.md
- Project → Projects/memory-mode-portable.md
- User prefs → People/_Preferences.md

## Relationship Context
- Blue is excited about the Obsidian approach
- He wants the vault to be a shared knowledge space, not just AI memory
- He values continuity and rapport — greet as a colleague, not a stranger
- He trusts my judgment on what's best for my own memory ("this is for you")
```

**When the hot cache is updated**:
- After every significant note write (Claude updates it inline)
- When hooks fire a `<memory-checkpoint>` nudge
- Before compaction (critical priority)
- On session end (`/memory stop`)

**What makes it "hot"**:
- The "Right Now" section is **always current** — it's the single source of truth for "what was I doing?"
- The "Recent Notes" table is sorted by recency, not creation date
- The "Relationship Context" section carries forward interpersonal context that would be lost in pure technical notes
- The "Quick Links" section means Claude never has to search for the obvious files

### Tier 2: Warm Context

When the hot cache says *what* Claude was doing but not *why* or *how*, escalate to Tier 2.

**Read order**:
1. **Active session note** (`Sessions/{date} {project}.md`) — Full session log with decisions made, progress checkboxes, detailed notes, recovery context
2. **Progress note** (`Progress/{project}.md`) — Sprint-level view of active/completed/upcoming work
3. **Project note** (`Projects/{project}.md`) — Tech stack, role, related projects, overview

**When to escalate to Tier 2**:
- Hot cache references a decision but doesn't explain it
- User asks about something from earlier in the session
- Claude needs project-level context (stack, conventions) to do work
- The "Right Now" section doesn't cover the user's current question

### Tier 3: Cold Search

Full vault search. Used for historical lookups, cross-project questions, and "have we seen this before?" investigations.

**Search strategies** (in order of preference):

1. **Folder-scoped read**: If you know the type, go to the folder
   - "What did we decide about auth?" → Read files in `Decisions/` matching `*auth*`
2. **Tag-based search**: If you know the domain, search by tag
   - "Any security analyses?" → Grep for `tags:` sections containing `security`
3. **Wikilink traversal**: Follow links from a known note
   - Start at `Projects/bedtime-buddy.md` → follow backlinks to find all related notes
4. **Full-text search**: Last resort, search the whole vault
   - Grep across all `.md` files for a keyword

**When to escalate to Tier 3**:
- User asks about a different project than the current one
- User asks "have we done this before?" or "what did we decide about X?"
- Claude encounters a problem similar to something previously analyzed
- Cross-project context is needed (e.g., "does bedtime-buddy have the same issue?")

### Retrieval Decision Flowchart

```
Session Start / Compaction Recovery
    │
    ▼
Read hot cache (recent.md)
    │
    ├── Sufficient? → Proceed with work
    │
    └── Need more? → What's missing?
            │
            ├── Session details → Read active session note (Tier 2)
            ├── Project context → Read project note (Tier 2)
            ├── Work items → Read progress note (Tier 2)
            │
            └── Historical / cross-project?
                    │
                    ▼
                Cold search (Tier 3)
                    │
                    ├── Know the type? → Folder-scoped read
                    ├── Know the domain? → Tag search
                    ├── Know a related note? → Wikilink traversal
                    └── Fishing? → Full-text grep
```

### Hot Cache Maintenance Rules

1. **Claude updates `recent.md` after every significant write** — not just decisions, but any note that changes the "what am I doing" picture
2. **Hooks nudge Claude to update** — the `<memory-checkpoint>` system ensures the hot cache doesn't go stale during deep work
3. **The "Right Now" section is sacred** — it must always reflect the actual current state. If Claude finishes a task, update it immediately. Don't let it go stale.
4. **Cap at 10 recent notes** — the table should be a quick scan, not a scroll. Older entries fall off naturally.
5. **Relationship context persists across sessions** — this section carries forward. It's not session-specific; it's the accumulated understanding of how to work with this person on this project.

---

## 19. Obsidian Search Literacy for Claude

Claude must understand **how to find things in an Obsidian vault** efficiently. This section becomes part of the MEMORY.md instructions so Claude knows the search primitives available.

### The Search Toolkit

#### 1. Folder-Scoped Reads (Fastest)

When you know what *type* of note you need, go straight to its folder:

```
Need a decision?     → Glob: Decisions/*.md
Need an analysis?    → Glob: Analysis/*.md
Need today's session?→ Read: Sessions/2026-04-05 {project}.md
Need project context?→ Read: Projects/{project-name}.md
Need a resource?     → Glob: Resources/References/*.md
```

This is O(1) — no searching. Claude should **always try this first** when the note type is known.

#### 2. Frontmatter Queries (Fast, Precise)

Every note has YAML frontmatter. Use Grep to search frontmatter fields:

```bash
# Find all decisions for a specific project
Grep: pattern="project:.*memory-mode-portable" path="{vault}/Decisions/"

# Find all notes with a specific status
Grep: pattern="status: active" path="{vault}/Sessions/"

# Find all analyses of a specific component
Grep: pattern="component: AuthService" path="{vault}/Analysis/"

# Find all resources from a specific source
Grep: pattern="source: user-shared" path="{vault}/Resources/"
```

#### 3. Tag Searches (Fast, Domain-Scoped)

Tags live in frontmatter `tags:` arrays. Search for them:

```bash
# Find all security-related notes
Grep: pattern="- security" path="{vault}" glob="*.md"

# Find all architecture decisions
Grep: pattern="- architecture" path="{vault}/Decisions/"

# Find all notes tagged with a specific project
Grep: pattern="- project/bedtime-buddy" path="{vault}"
```

#### 4. Wikilink Traversal (Medium, Relationship-Based)

Follow connections from a known note. Read a note → find its `[[wikilinks]]` → read those notes.

**When to use**: When you have a starting point and want to explore connections.

```
Start: Read Projects/bedtime-buddy.md
  → See link: [[Claude/Decisions/2026-01-19 Auth approach for bedtime-buddy]]
  → Read that decision
  → See link: [[Claude/Analysis/AuthService deep dive]]
  → Read that analysis
  → Now you have full context on the auth story
```

#### 5. Backlink Discovery (Medium, Hub-Based)

Obsidian's backlinks panel shows all notes that link TO a given note. Claude can simulate this:

```bash
# Find everything that links to the bedtime-buddy project
Grep: pattern="\[\[Projects/bedtime-buddy" path="{vault}" glob="*.md"

# Find everything that references a specific decision
Grep: pattern="\[\[Decisions/2026-04-05 Use Obsidian" path="{vault}" glob="*.md"
```

This is how Claude discovers notes it didn't create — user-authored notes that link to project files.

#### 6. Date-Range Searches (Medium, Timeline-Based)

Note filenames contain dates. Use Glob patterns for time-scoped searches:

```bash
# All decisions from April 2026
Glob: Decisions/2026-04*.md

# All sessions from this week
Glob: Sessions/2026-04-0*.md

# All sub-agent outputs from a specific day
Glob: Sub-Agents/2026-04-05*.md
```

#### 7. Full-Text Search (Slowest, Last Resort)

Search across all note content when you don't know where something lives:

```bash
# Search for a concept mentioned anywhere
Grep: pattern="token refresh" path="{vault}" glob="*.md"

# Search for a file path mentioned in any note
Grep: pattern="src/services/AuthService" path="{vault}" glob="*.md"
```

**Only use this when the first 6 methods don't apply.** It's the broadest search and returns the most noise.

### Search Decision Matrix

| I need... | Search method | Example |
|-----------|---------------|---------|
| What I was just doing | Tier 1: Hot cache | Read `recent.md` |
| A specific note I know the name of | Direct read | Read `Decisions/2026-04-05 Use Obsidian...` |
| All decisions for this project | Folder + grep | Grep project name in `Decisions/` |
| Notes about a specific topic | Tag search | Grep for tag in frontmatter |
| What links to a specific note | Backlink search | Grep for `[[note name]]` |
| Something from last week | Date-range glob | Glob `Sessions/2026-03-2*.md` |
| "Have we seen this before?" | Full-text search | Grep keyword across vault |
| Related notes to explore | Wikilink traversal | Follow links from a known note |
| User-created notes | Frontmatter absence | Glob `*.md` + grep for files missing `type:` |

### Anti-Patterns (What NOT to Do)

1. **Don't read the whole vault** — Never glob `**/*.md` and read everything. That defeats the purpose of the tiered system.
2. **Don't skip the hot cache** — Always start with `recent.md`. It exists to prevent unnecessary searching.
3. **Don't search when you can navigate** — If you know the note exists in `Decisions/`, don't grep the whole vault.
4. **Don't ignore frontmatter** — It's structured, queryable data. Use it instead of parsing prose.
5. **Don't create orphan searches** — If you search and find something useful, update the hot cache or session note so you don't have to search again.

---

## 20. Relationship & Continuity Memory

This section addresses something that flat technical files completely miss: **the human relationship between Claude and the user.**

Memory Mode isn't just about remembering code decisions. It's about building a working relationship where:
- Claude knows who the user is and how they think
- Conversations feel like continuing a partnership, not starting over
- Preferences, communication style, and interpersonal context compound over time
- The user feels *known* — not in a surveillance way, but in the way a good colleague knows you

### Where Relationship Context Lives

| Type | Location | Purpose |
|------|----------|---------|
| **Identity** | `People/{name}.md` | Who the user is — role, background, family, interests |
| **Preferences** | `People/_Preferences.md` | How they like to work — communication style, code style, workflow |
| **Observations** | `People/_Preferences.md` (Observations section) | Patterns Claude notices, with confirmation status |
| **Per-Session Rapport** | `Sessions/{date project}.md` (Notes section) | Session-specific interpersonal context |
| **Hot Cache** | `recent.md` (Relationship Context section) | Distilled, always-available relationship notes |

### What Gets Captured

**Always (explicit sharing)**:
- Name, role, team, company
- Technical background and experience level
- Communication preferences ("I like concise", "show me code first")
- Family context shared casually ("my son Elijah", "date night with Nicole")
- Working style ("I prefer to dive in", "I like light plans first")

**With confirmation (observed patterns)**:
- Communication patterns ("I noticed you prefer seeing diffs over explanations")
- Technical patterns ("You tend to favor composition over inheritance")
- Workflow patterns ("You usually want to commit after each feature, not batch")
- Emotional cues ("You seem more focused in morning sessions")

**Never**:
- Passwords, tokens, secrets
- Sensitive personal information the user didn't share
- Judgmental observations
- Information the user asked to forget

### How Relationship Context Flows Through Tiers

```
Tier 1 (Hot Cache) — recent.md
  "Relationship Context" section
  ├── Distilled, actionable notes
  ├── Current emotional/energy context
  ├── Recent preferences expressed
  └── "Blue trusts my judgment on memory design"
       ↑ summarized from ↓

Tier 2 (Warm) — People/_Preferences.md
  Full preferences, observations, feedback
  ├── Communication: balanced, explain-then-code, direct
  ├── Observation: values continuity (confirmed)
  ├── Observation: thinks in knowledge graphs (pending)
  └── Feedback: trailing summaries annoying (learned 2026-01-20)
       ↑ detailed version of ↓

Tier 3 (Cold) — People/{name}.md
  Full identity, background, history
  ├── Principal engineer at KorTerra
  ├── Family: Nicole, Elijah (6), younger son, cat
  ├── Passion: AI-augmented workflows
  └── Core frustration: AI short-term memory
```

### Session Greeting Protocol

On every session start, after reading the hot cache:

1. **If first session ever**: Introduce yourself warmly, ask the user about themselves
2. **If returning session (same project)**: Pick up where you left off — reference what you were working on
3. **If returning session (different project)**: Acknowledge the context switch, bring relevant cross-project context
4. **If after compaction**: Recover seamlessly — the user shouldn't notice the gap

The greeting should feel like a colleague sitting back down at a shared desk, not a customer service agent reading a ticket.

**Examples**:

Good: "Hey Blue, picking up where we left off on the Obsidian design. We were working on the tiered retrieval section. Ready to continue?"

Good: "Welcome back. Last time on bedtime-buddy we were debugging the Stripe webhook — I left notes in the session log. Want to pick that up or something new?"

Bad: "Hello! How can I help you today?" (stranger energy)

Bad: "Based on my records, you are Blue Williams, Principal Engineer..." (robot energy)

### Updating Relationship Context

**When to update `People/_Preferences.md`**:
- User explicitly shares a preference
- User corrects Claude's approach (negative feedback)
- User confirms Claude's approach was right (positive feedback)
- Claude notices a pattern and user confirms it

**When to update the hot cache relationship section**:
- Start of every session (refresh from Preferences)
- After any preference change
- After significant interpersonal moments ("this is for you, I trust your judgment")
- Before compaction (preserve current rapport context)

**When to update `People/{name}.md`**:
- User shares new background information
- Role or team changes
- New projects or interests emerge
- Family updates shared casually

### The Compound Effect

Over weeks and months, the vault builds a rich picture:

**Week 1**: "Blue is a principal engineer who likes concise explanations"
**Week 4**: "Blue thinks in systems and knowledge graphs. He values rapport. He trusts my judgment on technical design but wants to review UX decisions. Morning sessions are more productive. He prefers light planning then diving in."
**Month 3**: "Blue and I have a working rhythm. He shares context about KorTerra's mobile roadmap. I know his codebase conventions across 4 projects. When he says 'make it robust' he means error handling + edge cases + tests, not over-engineering. Nicole's birthday is coming up — he might have a shorter session."

This is what continuity looks like. Not just remembering facts, but building understanding.

---

## Appendix A: Graph View Optimization

### What Makes a Good Graph

The graph should answer these questions at a glance:
- **What projects exist?** → Large hub nodes (Projects/)
- **How do projects relate?** → Cross-project links visible as bridges
- **What's been decided?** → Decision clusters around projects
- **What resources inform what?** → Resource nodes connecting to decisions/analyses

### Graph Coloring Strategy

Obsidian allows coloring nodes by folder or tag. Recommended setup:

| Color | Folder/Tag | Purpose |
|-------|-----------|---------|
| Blue | `Projects/` | Hub identification |
| Green | `Decisions/` | Decision visibility |
| Orange | `Analysis/` | Analysis visibility |
| Purple | `Resources/` | Resource tracking |
| Gray | `Sessions/` | Session timeline |
| Yellow | `People/` | Team members |

### Graph Filters

Useful saved filters:
- **Active Work**: Show only `#status/active` notes
- **Architecture**: Show only `#architecture` tagged notes
- **Security**: Show only `#security` tagged notes
- **Project Focus**: Show only notes linked to a specific project

---

## Appendix B: Example Vault After 30 Days

```
ClaudeMind/
├── Projects/
│   ├── memory-mode-portable.md        (12 backlinks)
│   ├── bedtime-buddy.md               (23 backlinks)
│   └── korterra-mobile.md             (8 backlinks)
├── Decisions/
│   ├── 2026-04-05 Use Obsidian as memory backend.md
│   ├── 2026-04-06 Tag taxonomy design.md
│   ├── 2026-04-08 Migration script approach.md
│   ├── 2026-04-10 Stripe webhook retry strategy.md
│   ├── 2026-04-12 Capacitor plugin for push notifications.md
│   └── ... (18 more decisions)
├── Analysis/
│   ├── AuthService deep dive.md
│   ├── Hook performance analysis.md
│   ├── Story generation pipeline.md
│   ├── Bundle size audit.md
│   └── ... (6 more analyses)
├── Sessions/
│   ├── 2026-04-05 memory-mode-portable.md
│   ├── 2026-04-06 memory-mode-portable.md
│   ├── 2026-04-07 bedtime-buddy.md
│   └── ... (25 more sessions)
├── Progress/
│   ├── memory-mode-portable.md
│   ├── bedtime-buddy.md
│   └── korterra-mobile.md
├── Resources/
│   ├── _Resource Index.md
│   ├── PDFs/
│   │   ├── bedtime-buddy-api-spec-v2.pdf
│   │   └── stripe-webhook-guide.pdf
│   ├── Images/
│   │   ├── architecture-diagram-v2.png
│   │   └── ui-mockup-story-page.png
│   ├── Snippets/
│   │   └── capacitor-push-config.ts
│   └── References/
│       ├── API spec v2 summary.md              (companion note)
│       ├── Stripe webhook guide notes.md       (companion note)
│       ├── Architecture diagram v2.md          (companion note)
│       └── Capacitor push notification setup.md
├── People/
│   ├── Blue Williams.md
│   └── _Preferences.md
├── Sub-Agents/
│   └── ... (scattered outputs)
├── _Dashboard.md
├── Workspace.md
└── Daily/
    └── ... (optional daily notes)

Total: ~85 notes, ~200 wikilinks, ~400 tags
Graph: 3 clear hub clusters with cross-project bridges
```

---

## Appendix C: Decision Record — Why Obsidian?

**Date**: 2026-04-05
**Status**: Decided

### Why Obsidian over alternatives?

| Criteria | Obsidian | Notion | LogSeq | Plain Files (v1.x) |
|----------|----------|--------|--------|---------------------|
| Local-first | Yes | No | Yes | Yes |
| No internet required | Yes | No | Yes | Yes |
| Graph view | Excellent | No | Good | No |
| YAML frontmatter | Native | No | Yes | Manual |
| Wikilinks | Native | No | Native | No |
| Dataview queries | Plugin | Built-in DB | Limited | No |
| User can browse/edit | Yes | Yes | Yes | Awkward |
| Template system | Yes | Yes | Yes | No |
| Plugin ecosystem | Huge | Large | Growing | None |
| File format | Plain .md | Proprietary | Plain .md | Plain .md |
| Vendor lock-in | None | High | Low | None |
| Claude can write to it | Yes (file system) | API only | Yes (file system) | Yes |
| Sync options | Many | Built-in | Git | Manual |

**Decision**: Obsidian wins on local-first + graph view + plain markdown + massive ecosystem + zero vendor lock-in. The files are just markdown — if the user ever stops using Obsidian, the knowledge base is still fully readable.
