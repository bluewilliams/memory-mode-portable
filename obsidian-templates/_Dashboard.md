---
type: meta
tags:
  - meta
  - dashboard
aliases:
  - Home
  - Dashboard
---

# Claude Mind - Dashboard

> AI-powered knowledge base. Browse, search, and discover.

---

# Now

## Needs Attention

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  summary AS "Focus",
  type AS "Type",
  project AS "Project",
  date AS "Date"
FROM ""
WHERE status = "stub" AND !contains(file.path, "_Templates")
SORT date DESC
```

## Active Investigations

Investigation hubs (`#investigation` tag) with their linked session counts. Click a hub to see its full timeline; the hub note auto-finds every session that links to it.

```dataview
TABLE WITHOUT ID
  file.link AS "Investigation",
  summary AS "Focus",
  status AS "Status",
  length(filter(dv.pages('#session'), s => contains(string(s.investigates), file.name))) AS "Sessions"
FROM #investigation OR #analysis
WHERE (status = "living" OR status = "active") AND !contains(file.path, "_Templates")
SORT length(filter(dv.pages('#session'), s => contains(string(s.investigates), file.name))) DESC
LIMIT 8
```

## Today and Yesterday

What was touched in the last 48 hours, across all categories. Useful for "where did I leave off."

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  summary AS "Focus",
  type AS "Type",
  project AS "Project"
FROM ""
WHERE type AND !contains(file.path, "_Templates") AND !contains(file.path, ".claude-state")
WHERE file.mtime >= date(today) - dur(2 days)
SORT file.mtime DESC
LIMIT 12
```

## Active Sessions

```dataview
TABLE WITHOUT ID
  file.link AS "Session",
  summary AS "Focus",
  tickets AS "Tickets",
  project AS "Project"
FROM #session
WHERE status = "active" AND !contains(file.path, "_Templates")
SORT date DESC
```

## Active Projects

```dataview
TABLE WITHOUT ID
  file.link AS "Project",
  status AS "Status",
  stack AS "Stack"
FROM #project
WHERE status = "active" AND !contains(file.path, "_Templates")
SORT file.name ASC
```

## Active Threads

Multi-day work streams - tickets touched across multiple sessions.

```dataview
TABLE WITHOUT ID
  ticket AS "Ticket",
  length(rows) AS "Days",
  rows.summary AS "Focus",
  rows.file.link AS "Sessions"
FROM #session
WHERE tickets AND !contains(file.path, "_Templates")
FLATTEN tickets AS ticket
GROUP BY ticket
WHERE length(rows) > 1
SORT length(rows) DESC
LIMIT 10
```

---

# Recent

## Recently Changed

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  summary AS "Focus",
  type AS "Type",
  project AS "Project"
FROM ""
WHERE type AND !contains(file.path, "_Templates") AND !contains(file.path, ".claude-state")
SORT file.mtime DESC
LIMIT 10
```

## Recent Decisions

```dataview
TABLE WITHOUT ID
  file.link AS "Decision",
  summary AS "Focus",
  project AS "Project",
  status AS "Status"
FROM #decision
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Analysis

```dataview
TABLE WITHOUT ID
  file.link AS "Analysis",
  summary AS "Focus",
  project AS "Project",
  component AS "Component"
FROM #analysis
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Brags

```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  summary AS "Focus",
  project AS "Project",
  quarter AS "Quarter"
FROM #brag
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Resources

```dataview
TABLE WITHOUT ID
  file.link AS "Resource",
  summary AS "Focus",
  category AS "Category",
  source AS "Source"
FROM #resource
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

# Reference

## Sub-Agent Activity

```dataview
TABLE WITHOUT ID
  file.link AS "Output",
  summary AS "Focus",
  project AS "Project",
  agent AS "Agent"
FROM #subagent
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Stats

`$= "**" + dv.pages('#project').where(p => !p.file.path.includes('_Templates')).length + "** projects | **" + dv.pages('#decision').where(p => !p.file.path.includes('_Templates')).length + "** decisions | **" + dv.pages('#analysis').where(p => !p.file.path.includes('_Templates')).length + "** analyses | **" + dv.pages('#session').where(p => !p.file.path.includes('_Templates')).length + "** sessions | **" + dv.pages('#brag').where(p => !p.file.path.includes('_Templates')).length + "** brags | **" + dv.pages('#resource').where(p => !p.file.path.includes('_Templates')).length + "** resources"`

---

*Quick links: [[Claude/Workspace|Workspace]] | [[Claude/People/Blue Williams|Profile]] | [[Claude/People/_Preferences|Preferences]] | [[Claude/Brag/_Brag Dashboard|Brag Dashboard]] | [[Claude/Resources/_Resource Index|Resources]]*
