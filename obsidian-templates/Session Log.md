---
type: session
project: "[[Claude/Projects/]]"
date: {{date}}
branch: 
status: active
summary: "One-line description of the session focus - keep it scannable"
tickets: []
continues: 
investigates: 
also_touches: 
related_to: 
tags:
  - session
---

# Session: {{title}} ({{date}})

## Thread
- **Previous**: (set `continues:` frontmatter to link prior session if picking up work)
- **Investigation hub**: (set `investigates:` frontmatter to link to a long-running Analysis hub if one exists)
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
- **Sessions on the same investigation**:
  ```dataview
  LIST FROM #session
  WHERE this.investigates AND investigates = this.investigates
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

---

## Related Notes

Explicit wikilinks for navigation. Populate as the session progresses so the graph view and click-through navigation work.

**Investigation hub** (if any)
- (link to the active Analysis hub note, e.g. `[[Claude/Analysis/{hub-title}]]`)

**Other sessions in this thread**
- (link to prior and following sessions on the same task)

**Related analysis or decision notes**
- (link to relevant analyses, decisions, or resources touched today)
