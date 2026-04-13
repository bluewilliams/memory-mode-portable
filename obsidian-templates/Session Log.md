---
type: session
project: "[[Claude/Projects/]]"
date: {{date}}
branch: 
status: active
summary: "One-line description of the session focus - keep it scannable"
tickets: []
continues: 
tags:
  - session
---

# Session: {{title}} ({{date}})

## Thread
- **Previous**: (set `continues:` frontmatter to link prior session if picking up work)
- **Next**: 
  ```dataview
  LIST FROM #session WHERE continues = this.file.link SORT date ASC
  ```
- **Related sessions** (same tickets):
  ```dataview
  LIST FROM #session
  WHERE tickets AND this.tickets AND any(map(tickets, (t) => contains(this.tickets, t)))
    AND file.name != this.file.name
    AND !contains(file.path, "_Templates")
  SORT date DESC
  LIMIT 5
  ```

## Current Task
What we're working on.

## Progress
- 🔄 Current step
- ⏳ Next step

## Blockers
None.

## Done When
- [ ] Completion criteria

## Decisions Made
- (none yet)

## What Didn't Work
Approaches tried and abandoned this session, with brief reasons why. This
helps future sessions avoid repeating dead ends.

## Notes

## Key Context for Recovery
If reading this after compaction: summarize the essential state here.
