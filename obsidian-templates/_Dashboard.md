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

## Active Projects

```dataview
TABLE WITHOUT ID
  file.link AS "Project",
  status AS "Status",
  stack AS "Stack"
FROM #project
WHERE status = "active"
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
WHERE status = "active"
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
SORT date DESC
LIMIT 10
```

---

## Stats

- **Total Projects**: `$= dv.pages('#project').length`
- **Total Decisions**: `$= dv.pages('#decision').length`
- **Total Analyses**: `$= dv.pages('#analysis').length`
- **Total Resources**: `$= dv.pages('#resource').length`
- **Total Sessions**: `$= dv.pages('#session').length`
