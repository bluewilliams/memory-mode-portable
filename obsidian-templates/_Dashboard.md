---
type: meta
tags:
  - meta
  - dashboard
aliases:
  - Home
  - Dashboard
---

# Claude Mind --- Dashboard

> AI-powered knowledge base. Browse, search, and discover.

---

## Needs Attention

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  type AS "Type",
  project AS "Project",
  date AS "Date"
FROM ""
WHERE status = "stub" AND !contains(file.path, "_Templates")
SORT date DESC
```

---

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

---

## Active Sessions

```dataview
TABLE WITHOUT ID
  file.link AS "Session",
  project AS "Project",
  branch AS "Branch"
FROM #session
WHERE status = "active" AND !contains(file.path, "_Templates")
SORT date DESC
```

---

## Recent Decisions

```dataview
TABLE WITHOUT ID
  file.link AS "Decision",
  project AS "Project",
  status AS "Status",
  category AS "Category"
FROM #decision
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 15
```

---

## Recent Analysis

```dataview
TABLE WITHOUT ID
  file.link AS "Analysis",
  project AS "Project",
  component AS "Component"
FROM #analysis
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

## Recent Brags

```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  project AS "Project",
  quarter AS "Quarter"
FROM #brag
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

## Recent Resources

```dataview
TABLE WITHOUT ID
  file.link AS "Resource",
  category AS "Category",
  source AS "Source"
FROM #resource
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

## Sub-Agent Activity

```dataview
TABLE WITHOUT ID
  file.link AS "Output",
  project AS "Project",
  agent AS "Agent",
  task AS "Task"
FROM #subagent
WHERE !contains(file.path, "_Templates")
SORT date DESC
LIMIT 10
```

---

## Stats

- **Total Projects**: `$= dv.pages('#project').where(p => !p.file.path.includes('_Templates')).length`
- **Total Decisions**: `$= dv.pages('#decision').where(p => !p.file.path.includes('_Templates')).length`
- **Total Analyses**: `$= dv.pages('#analysis').where(p => !p.file.path.includes('_Templates')).length`
- **Total Resources**: `$= dv.pages('#resource').where(p => !p.file.path.includes('_Templates')).length`
- **Total Sessions**: `$= dv.pages('#session').where(p => !p.file.path.includes('_Templates')).length`
- **Total Brags**: `$= dv.pages('#brag').where(p => !p.file.path.includes('_Templates')).length`
