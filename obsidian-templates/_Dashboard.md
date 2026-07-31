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

> [!tip]- Searching this dashboard
> Use the **filter box** below: it searches every row on this page (summary, note name, tickets, status, type) and narrows all sections as you type. In-file search (`Cmd+F`) will NOT match the tables - they are live Dataview projections and their text is not stored in this file. To search full note content across the vault, use **global search** (`Cmd+Shift+F`); the static `_Index.md` breadcrumbs are searchable one-line digests of the same rows.

```dataviewjs
const EXCLUDED = p => p.file.path.includes("_Templates") || p.file.path.includes(".claude-state");
const wrap = dv.el("div", "");

const input = wrap.createEl("input", { type: "search", placeholder: "Filter the dashboard: summary, note name, ticket, status, type..." });
input.style.cssText = "width:100%;padding:8px 12px;margin:2px 0 14px;font-size:0.95em;border-radius:8px;border:1px solid var(--background-modifier-border);background:var(--background-primary);color:var(--text-normal);";
const body = wrap.createEl("div");

const fmt = v => (v && v.toFormat) ? v.toFormat("MMM dd, yyyy") : (v == null ? "" : String(v));
const asList = v => v == null ? [] : (Array.isArray(v) ? v : (v.values ? v.values : [v]));
const txt = v => v == null ? "" : (Array.isArray(v) ? v.map(txt).join(" ") : String(v));

function anchor(parent, name) {
  const a = parent.createEl("a", { text: name, cls: "internal-link", href: name });
  a.setAttr("data-href", name);
  a.setAttr("rel", "noopener");
  return a;
}

const sections = [];
function addSection(title, headers, rows) {
  if (rows.length) sections.push({ title, headers, rows });
}
const row = (cells, ...hayParts) => ({ cells, hay: hayParts.map(txt).join(" ").toLowerCase() });

// Working On (Progress notes with living/active status)
const progress = dv.pages("#progress")
  .where(p => !EXCLUDED(p) && (p.status == "living" || p.status == "active"))
  .array().sort((a, b) => (b.updated?.toMillis?.() ?? 0) - (a.updated?.toMillis?.() ?? 0));
addSection("Working On", ["Focus", "Next Step", "Progress", "Updated"],
  progress.map(p => row(
    [p.summary ?? "", p.next ?? "", { link: p.file.name }, fmt(p.updated)],
    p.summary, p.next, p.file.name, fmt(p.updated))));

// Active Investigations (living/active Analysis hubs + linked session counts)
const allSessions = dv.pages("#session").where(s => !EXCLUDED(s));
const hubs = dv.pages("#analysis")
  .where(p => !EXCLUDED(p) && (p.status == "living" || p.status == "active"));
const invRows = hubs.array().map(h => {
  const count = allSessions.where(s => s.investigates && String(s.investigates).includes(h.file.name)).length;
  return { r: row([h.summary ?? h.file.name, { link: h.file.name }, h.status ?? "", String(count)],
    h.summary, h.file.name, h.status), count };
}).sort((a, b) => b.count - a.count).slice(0, 8).map(x => x.r);
addSection("Active Investigations", ["Focus", "Investigation", "Status", "Sessions"], invRows);

// This Week's Sessions
const cutoff = dv.luxon.DateTime.now().minus({ days: 7 });
const week = allSessions
  .where(s => s.date?.toMillis && s.date.toMillis() >= cutoff.toMillis())
  .array().sort((a, b) => b.date.toMillis() - a.date.toMillis());
addSection("This Week's Sessions", ["Focus", "Session", "Tickets", "Date"],
  week.map(s => row(
    [s.summary ?? "", { link: s.file.name }, asList(s.tickets).join(", "), fmt(s.date)],
    s.summary, s.file.name, asList(s.tickets).join(" "), fmt(s.date))));

// Active Threads (tickets touched across multiple sessions)
const byTicket = {};
for (const s of allSessions.array()) {
  for (const t of asList(s.tickets)) (byTicket[t] ??= []).push(s);
}
const threads = Object.entries(byTicket)
  .filter(([, ss]) => ss.length > 1)
  .sort((a, b) => b[1].length - a[1].length).slice(0, 10)
  .map(([t, ss]) => row(
    [t, String(ss.length), ss.map(s => s.summary).filter(Boolean).join(" | "), { links: ss.map(s => s.file.name) }],
    t, ss.map(s => s.summary).join(" "), ss.map(s => s.file.name).join(" ")));
addSection("Active Threads", ["Ticket", "Days", "Focus", "Sessions"], threads);

// Needs Attention (stubs)
const stubs = dv.pages().where(p => !EXCLUDED(p) && p.status == "stub")
  .array().sort((a, b) => (b.date?.toMillis?.() ?? 0) - (a.date?.toMillis?.() ?? 0));
addSection("Needs Attention", ["Focus", "Note", "Type", "Date"],
  stubs.map(p => row(
    [p.summary ?? "", { link: p.file.name }, p.type ?? "", fmt(p.date)],
    p.summary, p.file.name, p.type)));

// Recently Changed (real notes only)
const changed = dv.pages().where(p => !EXCLUDED(p) && p.type && p.type != "index" && p.type != "meta")
  .array().sort((a, b) => b.file.mtime.toMillis() - a.file.mtime.toMillis()).slice(0, 12);
addSection("Recently Changed", ["Focus", "Note", "Type"],
  changed.map(p => row(
    [p.summary ?? "", { link: p.file.name }, p.type ?? ""],
    p.summary, p.file.name, p.type)));

// Recent by category
const recent = (tag, extra, extraKey) => dv.pages(tag).where(p => !EXCLUDED(p))
  .array().sort((a, b) => (b.date?.toMillis?.() ?? 0) - (a.date?.toMillis?.() ?? 0)).slice(0, 10)
  .map(p => row(
    [p.summary ?? "", { link: p.file.name }, extraKey ? (p[extraKey] ?? "") : (p.status ?? ""), fmt(p.date)],
    p.summary, p.file.name, extraKey ? p[extraKey] : p.status, fmt(p.date)));
addSection("Recent Decisions", ["Focus", "Decision", "Status", "Date"], recent("#decision"));
addSection("Recent Analysis", ["Focus", "Analysis", "Status", "Date"], recent("#analysis"));
addSection("Recent Brags", ["Focus", "Accomplishment", "Quarter", "Date"], recent("#brag", true, "quarter"));
addSection("Recent Resources", ["Focus", "Resource", "Category", "Date"], recent("#resource", true, "category"));

// Active Projects
const projects = dv.pages("#project").where(p => !EXCLUDED(p) && p.status == "active")
  .array().sort((a, b) => a.file.name.localeCompare(b.file.name));
addSection("Active Projects", ["Project", "Status", "Stack"],
  projects.map(p => row(
    [{ link: p.file.name }, p.status ?? "", txt(p.stack)],
    p.file.name, p.status, p.stack)));

// Sub-Agent Activity
const agents = dv.pages("#subagent").where(p => !EXCLUDED(p))
  .array().sort((a, b) => (b.date?.toMillis?.() ?? 0) - (a.date?.toMillis?.() ?? 0)).slice(0, 10);
addSection("Sub-Agent Activity", ["Focus", "Output", "Agent"],
  agents.map(p => row(
    [p.summary ?? "", { link: p.file.name }, p.agent ?? ""],
    p.summary, p.file.name, p.agent)));

function render(q) {
  body.empty();
  const query = (q ?? "").trim().toLowerCase();
  let shown = 0;
  for (const sec of sections) {
    const rows = query ? sec.rows.filter(r => r.hay.includes(query)) : sec.rows;
    if (!rows.length) continue;
    shown++;
    body.createEl("h2", { text: query ? `${sec.title} (${rows.length})` : sec.title });
    const table = body.createEl("table");
    const trh = table.createEl("thead").createEl("tr");
    sec.headers.forEach(h => trh.createEl("th", { text: h }));
    const tbody = table.createEl("tbody");
    for (const r of rows) {
      const tr = tbody.createEl("tr");
      for (const c of r.cells) {
        const td = tr.createEl("td");
        const isObj = c != null && typeof c === "object";
        if (isObj && c.link) anchor(td, c.link);
        else if (isObj && c.links) c.links.forEach((n, i) => { if (i) td.appendText(", "); anchor(td, n); });
        else td.appendText(c == null ? "" : String(c));
      }
    }
  }
  if (!shown) body.createEl("p", { text: query ? `No rows match "${q}".` : "Nothing to show yet." });

  const count = tag => dv.pages(tag).where(p => !EXCLUDED(p)).length;
  body.createEl("p", { text: `${count("#project")} projects | ${count("#decision")} decisions | ${count("#analysis")} analyses | ${count("#session")} sessions | ${count("#brag")} brags | ${count("#resource")} resources` });
}
input.addEventListener("input", () => render(input.value));
render("");
```

---

*Quick links: [[Claude/Workspace|Workspace]] | [[Claude/People/Blue Williams|Profile]] | [[Claude/People/_Preferences|Preferences]] | [[Claude/Brag/_Brag Dashboard|Brag Dashboard]] | [[Claude/Resources/_Resource Index|Resources]]*
