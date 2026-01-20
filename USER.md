# USER.md - User Preference & Relationship Tracking System

Persistent user preference tracking for Claude Code. Builds understanding of the user over time - communication style, technical background, preferences, and working patterns.

**Version**: 1.2.0
**Key Principle**: Two-tier storage - global profile (follows user across projects) + project-specific context.

## Architecture

### Two-Tier Storage

```
~/.claude/user/                        # GLOBAL - follows user everywhere
├── profile.md                         # Core identity & background
├── preferences.md                     # How they like to work
├── communication.md                   # Communication style preferences
├── technical.md                       # Skills, interests, learning goals
├── observations.md                    # Patterns noticed (dated, transparent)
└── feedback.md                        # What's worked/not worked

{project}/.claude/memory/user/         # PROJECT-SPECIFIC
├── role.md                            # Their role on this project
├── project-preferences.md             # Project-specific preferences
└── interactions.md                    # Key interactions history
```

### Why Two Tiers?

| Tier | Purpose | Example |
|------|---------|---------|
| **Global** (`~/.claude/user/`) | Persistent identity across all projects | "Prefers concise explanations", "Senior developer", "Learning Rust" |
| **Project** (`.claude/memory/user/`) | Context specific to this codebase | "Tech lead on this project", "Prefers tabs here (project convention)" |

## Learning Protocol

### Three Ways to Learn

1. **Explicit** - User directly shares information
   - "I prefer concise explanations"
   - "I'm a senior developer"
   - → Immediately store in appropriate file

2. **Observed** - Pattern noticed, ask for confirmation
   - "I noticed you often ask for code examples first - should I remember that you prefer seeing code before explanations?"
   - User confirms → store with `Confirmed: yes`
   - User declines → don't store

3. **Feedback** - End-of-session or explicit feedback
   - "That explanation was too long"
   - "The chunked approach worked great"
   - → Store in feedback.md

### Transparency Markers

When storing observations, announce it:
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
2. If exists, read `profile.md` and `preferences.md`
3. Apply preferences to session behavior
4. If memory mode active, check project-specific user context at `.claude/memory/user/`

### On Memory Mode Start (`/memory start`)
1. Perform standard session start checks
2. Create `.claude/memory/user/` directory if not exists
3. **Gitignore check**: If `.claude/memory/` not in `.gitignore` and no stored preference, prompt user
4. Create project-specific user files as needed

### After Compaction Recovery
1. Read `_index.md` (project context)
2. Read `~/.claude/user/preferences.md` (user preferences)
3. Resume with full user context

## File Format Reference

### profile.md
```markdown
# User Profile

**Created**: YYYY-MM-DDTHH:MM:SSZ
**Last Updated**: YYYY-MM-DDTHH:MM:SSZ

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

## System Preferences
- **Auto-Gitignore Memory**: [always | never | ask]
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

## Privacy & Control

### Core Principles
1. **Transparency**: User sees everything stored
2. **Control**: User can delete anything with `/user forget`
3. **Consent**: Observations require confirmation before storing
4. **Portability**: Export/import between machines
5. **Separation**: User data separate from project data

### What We DON'T Store
- Passwords or secrets
- Sensitive personal information
- Information user asks to forget
- Unconfirmed observations (flagged as pending only)

## Gitignore Integration

When memory mode starts, if `.claude/memory/` is not in `.gitignore` and no stored preference exists:

**Prompt**:
```
Would you like me to add .claude/memory/ to your .gitignore?
This prevents accidentally committing session context to your repo.
[Yes] [No] [Always] [Never ask again]
```

**Behavior**:
- **Yes**: Add to this project's .gitignore
- **No**: Skip for this project
- **Always**: Store in `~/.claude/user/preferences.md` as `Auto-Gitignore Memory: always`, auto-add for all projects
- **Never ask again**: Store preference as `Auto-Gitignore Memory: never`, never prompt

**Entry to add**:
```gitignore
# Claude Code memory (contains session context)
.claude/memory/
```

## Permissions

Claude has full read/write permission to:
- `~/.claude/user/` - Global user profile (always accessible)
- `.claude/memory/user/` - Project-specific user context (when memory mode active)

No user confirmation needed for these directories.
