---
type: meta
tags:
  - meta
  - brag
  - dashboard
aliases:
  - Brag Dashboard
  - Accomplishments
---

# Brag Dashboard

> Significant accomplishments captured automatically by Claude and manually by you.
> Use this at review time to remember everything you did.

---

## Current Quarter

```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  project AS "Project",
  date AS "Date"
FROM #brag
WHERE quarter = this.file.frontmatter.current_quarter
SORT date DESC
```

---

## This Year

```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  project AS "Project",
  date AS "Date",
  quarter AS "Quarter"
FROM #brag
WHERE date >= date(soy)
SORT date DESC
```

---

## By Quarter

### Q2 2026
```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  project AS "Project",
  date AS "Date"
FROM #brag
WHERE quarter = "Q2 2026"
SORT date DESC
```

### Q1 2026
```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  project AS "Project",
  date AS "Date"
FROM #brag
WHERE quarter = "Q1 2026"
SORT date DESC
```

---

## By Project

```dataview
TABLE WITHOUT ID
  file.link AS "Accomplishment",
  date AS "Date",
  quarter AS "Quarter"
FROM #brag
GROUP BY project
SORT date DESC
```

---

## Stats

- **Total Accomplishments**: `$= dv.pages('#brag').length`
- **This Quarter**: `$= dv.pages('#brag').where(p => p.quarter == "Q2 2026").length`
- **Projects Represented**: `$= dv.pages('#brag').project.distinct().length`
