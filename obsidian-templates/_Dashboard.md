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

> AI-powered knowledge base. Browse, search, and discover. The **Focus** column is the subject of the work; note links are the receipts.

---

# Working On

The live per-project working state, projected from `Progress/` notes (updated at checkpoints). This is the "what are we working on" surface; everything below is evidence and history.

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  next AS "Next Step",
  file.link AS "Progress",
  updated AS "Updated"
FROM #progress
WHERE (status = "living" OR status = "active") AND !contains(file.path, "_Templates")
SORT updated DESC
```

## Active Investigations

Investigation hubs (Analysis notes with `status: living` or `active`) with their linked session counts. Click a hub for its full timeline.

```dataviewjs
const hubs = dv.pages('"Claude/Analysis"')
  .where(p => (p.status === "living" || p.status === "active") && !p.file.path.includes("_Templates"));

const sessions = dv.pages('#session')
  .where(s => !s.file.path.includes("_Templates"));

const rows = hubs.map(h => {
  const count = sessions.where(s => {
    if (!s.investigates) return false;
    return String(s.investigates).includes(h.file.name);
  }).length;
  return [h.summary || h.file.name, h.file.link, h.status || "", count];
});

const sorted = rows.array().sort((a, b) => b[3] - a[3]).slice(0, 8);

dv.table(["Focus", "Investigation", "Status", "Sessions"], sorted);
```

## This Week's Sessions

Sessions from the last 7 days (regardless of status - a day's session is its day's work). Focus first; the filename is just date + project key.

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Session",
  tickets AS "Tickets",
  date AS "Date"
FROM #session
WHERE date >= date(today) - dur(7 days) AND !contains(file.path, "_Templates")
SORT date DESC
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

## Needs Attention

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Note",
  type AS "Type",
  date AS "Date"
FROM ""
WHERE status = "stub" AND !contains(file.path, "_Templates")
SORT date DESC
```

---

# Recent

## Recently Changed

Real notes only - breadcrumb indexes and meta files are excluded so write-through churn does not eat these slots.

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Note",
  type AS "Type"
FROM ""
WHERE type AND type != "index" AND type != "meta"
  AND !contains(file.path, "_Templates") AND !contains(file.path, ".claude-state")
SORT file.mtime DESC
LIMIT 12
```

## Recent Decisions

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Decision",
  status AS "Status",
  date AS "Date"
FROM #decision
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Analysis

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Analysis",
  status AS "Status",
  date AS "Date"
FROM #analysis
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Brags

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Accomplishment",
  quarter AS "Quarter"
FROM #brag
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

## Recent Resources

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Resource",
  category AS "Category"
FROM #resource
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

# Reference

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

## Sub-Agent Activity

```dataview
TABLE WITHOUT ID
  summary AS "Focus",
  file.link AS "Output",
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
