---
type: meta
tags:
  - meta
  - meeting
---

# Meeting Index

## Upcoming

```dataview
TABLE WITHOUT ID
  file.link AS "Meeting",
  summary AS "Focus",
  attendees AS "With",
  time AS "Time"
FROM #meeting
WHERE status = "prep" AND !contains(file.path, "_Templates")
SORT date ASC
```

## Recent

```dataview
TABLE WITHOUT ID
  file.link AS "Meeting",
  summary AS "Focus",
  attendees AS "With",
  date AS "Date"
FROM #meeting
WHERE status = "completed" AND !contains(file.path, "_Templates")
SORT date DESC
LIMIT 15
```

## By Person

```dataview
TABLE WITHOUT ID
  rows.file.link AS "Meetings",
  length(rows) AS "Count"
FROM #meeting
WHERE !contains(file.path, "_Templates")
FLATTEN attendees AS person
GROUP BY person
SORT length(rows) DESC
```
