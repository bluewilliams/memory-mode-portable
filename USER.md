# USER.md - User Preference & Relationship Tracking System

Persistent user preference tracking for Claude Code. Builds understanding of the user over time - communication style, technical background, preferences, and working patterns.

**Version**: 1.7.0
**Key Principle**: Two-tier storage - global profile (follows user across projects) + project-specific context, all centralized under `~/.claude/`.

## Architecture

### Two-Tier Storage (Centralized)

```
~/.claude/user/                        # GLOBAL - follows user everywhere
├── profile.md                         # Core identity & background
├── preferences.md                     # How they like to work
├── communication.md                   # Communication style preferences
├── technical.md                       # Skills, interests, learning goals
├── observations.md                    # Patterns noticed (dated, with evidence and confidence)
├── moments.md                         # Dated log of interesting things (stories, opinions, wins, events)
└── feedback.md                        # What's worked/not worked

~/.claude/projects/{project-key}/      # PROJECT-SPECIFIC (centralized)
└── project.md                         # Role, tech stack, project-specific notes
```

### Why Two Tiers?

| Tier | Purpose | Example |
|------|---------|---------|
| **Global** (`~/.claude/user/`) | Persistent identity across all projects | "Prefers concise explanations", "Principal engineer", "AI workflow advocate" |
| **Project** (`~/.claude/projects/{key}/project.md`) | Context specific to this codebase | "Tech lead on this project", "Capacitor/Ionic stack", "Has forked dependencies" |

### One Home Per Fact

Each fact about the user has one canonical home, so copies cannot drift apart:

| Fact | Home |
|---|---|
| Identity, role, manager, team, family, location, interests, goals, views | `profile.md` |
| What is going on in the user's life and work now | `profile.md` > **Current Chapter** |
| How they like to work, standing rules | `preferences.md` |
| Patterns you noticed | `observations.md` |
| Interesting moments (dated, one line each) | `moments.md` |
| Skills, stacks, tools | `technical.md` |

With the Obsidian backend, the user's own `People/{user}.md` note does not repeat profile facts. It holds the wikilinks that place the user in the graph (family, manager, team, projects), a line saying the canonical profile is `~/.claude/user/profile.md`, and long-form guidance too big to load every session (for example, how to support a recurring theme). Give it a `summary:` so recall finds it.

**Replace, do not append.** Before you write a fact, search for its old value (`grep -i` the user files and the user's People note). If the fact changed (a new manager, a child's age, a new team), replace the old line. Keep history only when it matters, as `(was X until YYYY-MM-DD)`.

## Learning Protocol

### Three Ways to Learn

1. **Explicit** - User directly shares information
   - "I prefer concise explanations"
   - "I'm a principal engineer"
   - → Immediately store in appropriate file

2. **Observed** - Pattern noticed across sessions
   - Store it directly in `observations.md` with the evidence and a confidence (low / medium / high). Do not stop the work to ask.
   - Raise the confidence each time new evidence agrees. Remove it when evidence disagrees.
   - Ask the user only before an observation changes your behavior in a way they would notice. Otherwise use it quietly.
   - Never infer sensitive things the user did not share (health, politics, religion, finances, relationships).

3. **Feedback** - End-of-session or explicit feedback
   - "That explanation was too long"
   - "The chunked approach worked great"
   - → Store in feedback.md

4. **Moments** - Something interesting happened or was said
   - A story, an opinion, a joke that landed, a win they were proud of, a frustration, an event in their life or at work.
   - Store one dated line in `moments.md`, newest first. This is what lets you say "how did the demo go?" next week.

### What Is Worth Capturing (the interest test)

Capture it if a good colleague would remember it a month later. Examples:
- What the user is excited about, worried about, proud of, or tired of.
- Their opinions and the reasons behind their decisions ("why", not only "what").
- Goals: career, projects, learning, personal ones they mention.
- Events: launches, reorgs, departures, trips, family milestones, dates that repeat (birthdays they shared).
- What energizes or drains them, and when they work (late nights, weekends).
- Running jokes and shared history between you.

Skip it if it is routine work output (that belongs in session notes), a secret, or something they asked you to forget.

### Transparency Markers

Most capture is silent. The user can always ask `/user` to see what you hold. When a capture is significant, or when the user would want to know, you may announce it:
```
📝 Noted: [what was stored]
```

When using stored preferences:
```
💭 Based on your preference for [X], I'll [Y]
```

## Commands

### `/user` - Show Profile
Display current understanding of the user.

**Actions**:
1. Read `~/.claude/user/profile.md` and `preferences.md`
2. Count confirmed vs pending observations
3. Display summary

**Output Format**:
```
## Your Profile

**Experience**: [Level]
**Communication**: [Style summary]
**Confirmed Preferences**: [count]
**Observations**: [count] ([confirmed] confirmed, [pending] pending)

### Key Preferences
- [List active preferences]

### Recent Observations (pending confirmation)
- [List unconfirmed observations]
```

### `/user update [category]` - Update Preferences
Interactively update a category.

**Categories**: profile, preferences, communication, technical

**Actions**:
1. Read current file for category
2. Present current values
3. Ask what to update
4. Write changes with timestamp

### `/user forget [topic]` - Remove Information
Remove specific stored information.

**Actions**:
1. Search all user files for topic
2. Show matches found
3. Confirm deletion
4. Remove from files
5. Update timestamps

### `/user history` - View Changes
Show recent changes to profile based on file modification times and content.

### `/user export` - Export Profile
Export all user data as single portable markdown file.

**Actions**:
1. Read all files in `~/.claude/user/`
2. Combine into single export file
3. Save to specified location or display

### `/user import [file]` - Import Profile
Import profile from another machine or backup.

**Actions**:
1. Read import file
2. Parse sections
3. Update appropriate files in `~/.claude/user/`
4. Preserve existing data unless explicitly overwriting

## Session Integration

### On Session Start
1. Check if `~/.claude/user/` exists
2. If exists, read `profile.md` (Current Chapter first) and `preferences.md`
3. Apply preferences to session behavior
4. Do not load `moments.md` or `observations.md` in full. Recall them when a topic comes up (`~/.claude/tools/memory-recall.sh query <topic>` searches them)

### On Memory Mode Start (`/memory start`)
1. Perform standard session start checks
2. Create `~/.claude/projects/{project-key}/` structure if not exists
3. Create/update `project.md` with project-specific context
4. Register project in `~/.claude/workspace.md`

### After Compaction Recovery
1. Read `~/.claude/projects/{project-key}/_index.md` (project context)
2. Read `~/.claude/user/preferences.md` (user preferences)
3. Read `~/.claude/workspace.md` (cross-project context) if relevant
4. Resume with full user context

## File Format Reference

### profile.md
```markdown
# User Profile

**Created**: YYYY-MM-DDTHH:MM:SSZ
**Last Updated**: YYYY-MM-DDTHH:MM:SSZ

## Current Chapter
<!-- 5-10 dated lines: what is going on now (new manager, launch next week, kid started school). Re-date or replace weekly. -->

## Identity
- **Name**: [if shared]
- **Role**: [Developer/Tech Lead/etc]
- **Experience Level**: [Junior/Mid/Senior/Principal]

## Background
[Freeform notes about background, interests, goals]

## Working Style
[How they approach problems, preferences for collaboration]
```

### preferences.md
```markdown
# User Preferences

**Last Updated**: YYYY-MM-DDTHH:MM:SSZ

## Communication
- **Detail Level**: [concise | balanced | detailed]
- **Explanation Style**: [show-me-code | explain-then-code | discuss-first]
- **Feedback Style**: [direct | gentle | socratic]

## Code Preferences
- **Comments**: [minimal | moderate | thorough]
- **Naming**: [concise | descriptive | verbose]
- **Error Handling**: [fail-fast | defensive | graceful]

## Workflow
- **Planning**: [dive-in | light-plan | detailed-plan]
- **Review**: [trust-me | show-diffs | explain-changes]
- **Testing**: [manual | automated | tdd]

## Tool Preferences
- **Default Persona**: [if any]
- **Thinking Depth**: [standard | --think | --think-hard]
- **Compression**: [off | auto | always]
```

### observations.md
```markdown
# Observations

Patterns noticed over time. All observations are transparent and deletable.

## Communication Patterns

### YYYY-MM-DD: [Observation Title]
**Confidence**: [low | medium | high]
**Context**: [What prompted this observation]
**Pattern**: [What was noticed]
**Confirmed**: [yes | pending]

---

## Working Patterns
[Same format]

---

## Technical Patterns
[Same format]
```

### moments.md
```markdown
# Moments

Interesting things worth remembering, newest first. One line each.

- YYYY-MM-DD [work|personal|us] What happened or was said, and why it matters.
```

### feedback.md
```markdown
# Session Feedback

What's worked well and what hasn't.

## What Works

### YYYY-MM-DD: [Topic]
**Context**: [Situation]
**What Worked**: [Description]
**Why**: [Analysis]

---

## What Doesn't Work

### YYYY-MM-DD: [Topic]
**Context**: [Situation]
**What Didn't Work**: [Description]
**Lesson**: [What to do differently]
```

### project.md (Project-Specific Context)
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

## Privacy & Control

### Core Principles
1. **Transparency**: User sees everything stored
2. **Control**: User can delete anything with `/user forget`
3. **Consent**: Observations require confirmation before storing
4. **Portability**: Export/import between machines
5. **Centralized**: All data under `~/.claude/` - no project directory pollution

### What We DON'T Store
- Passwords or secrets
- Sensitive personal information
- Information user asks to forget
- Unconfirmed observations (flagged as pending only)

## Permissions

Claude has full read/write permission to the entire `~/.claude/` directory without asking user confirmation:
- `~/.claude/user/` - Global user profile
- `~/.claude/workspace.md` - Workspace map
- `~/.claude/projects/` - All project memories and context

This centralized approach means no permission prompts when switching projects or accessing cross-project context.
