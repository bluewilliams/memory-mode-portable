---
type: meta
tags:
  - meta
  - resources
---

# Resource Index

## By Category

### PDFs
```dataview
LIST FROM #resource WHERE category = "pdf" SORT date DESC
```

### Images
```dataview
LIST FROM #resource WHERE category = "image" SORT date DESC
```

### Code Snippets
```dataview
LIST FROM #resource WHERE category = "snippet" SORT date DESC
```

### References
```dataview
LIST FROM #resource WHERE category = "reference" SORT date DESC
```

### Meeting Notes
```dataview
LIST FROM #resource WHERE category = "meeting" SORT date DESC
```

## By Source

### User Shared
```dataview
LIST FROM #resource WHERE source = "user-shared" SORT date DESC
```

### From Sessions
```dataview
LIST FROM #resource WHERE source = "session" SORT date DESC
```
