import * as C from "./core.js";
import * as storage from "./storage.js";
import { importDocument } from "./imports.js";
import { LocalRecorder } from "./recorder.js";
import { trends, ask, evidenceMap } from "./insights.js";
const $ = (s) => document.querySelector(s),
  esc = (x) =>
    String(x ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
let state = C.emptyState(),
  ready = false,
  busy = false,
  cloud = null;
const modal = $("#modal");
const paths = {
  today: "Today",
  care: "My care",
  sources: "Sources",
  review: "Review",
  tasks: "Follow-through",
  visits: "Visits",
  questions: "Questions",
  changes: "Activity",
  brief: "Care brief",
  settings: "Settings",
};
const icons = {
  today: "M3 11 12 3l9 8v10h-6v-7H9v7H3Z",
  care: "M20 5c-4-4-8 1-8 1S8 1 4 5c-5 6 8 15 8 15S25 11 20 5Z",
  sources: "M5 3h10l4 4v14H5ZM14 3v5h5M8 12h8M8 16h8",
  review: "m5 12 4 4L19 6M21 12v8H3V4h12",
  tasks: "M9 6h12M9 12h12M9 18h12M3 5l1 1 2-2M3 11l1 1 2-2M3 17l1 1 2-2",
  visits: "M4 5h16v16H4ZM4 10h16M8 2v6M16 2v6",
  questions:
    "M9 8a3 3 0 1 1 4 3c-1 1-1 2-1 3M12 17h.01M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
  changes: "M3 12h4l3-8 4 16 3-8h4",
  brief: "M5 3h14v18H5ZM8 8h8M8 12h8M8 16h5",
  settings:
    "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2",
};
const svg = (name) =>
  `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${icons[name] || icons.sources}" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const button = (label, action, data = "", cls = "") =>
  `<button class="btn ${cls}" data-action="${action}" data-id="${esc(data)}">${label}</button>`;
const badge = (text, type = "") =>
  `<span class="badge ${type}">${esc(text)}</span>`;
const fmt = (d) =>
  d
    ? new Date(d.length === 10 ? `${d}T12:00:00` : d).toLocaleDateString(
        undefined,
        { month: "short", day: "numeric", year: "numeric" },
      )
    : "Date not provided";
function toast(message) {
  $("#notice").textContent = message;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => ($("#notice").textContent = ""), 7000);
}
function footer() {
  return `<div class="footer-note"><span>CareInOne · A little more clarity, every day.</span><span><a href="#privacy">Privacy</a> &nbsp;·&nbsp; <a href="#support">Help</a> &nbsp;·&nbsp; Browser storage</span></div>`;
}
function heading(title, subtitle, action = "") {
  return `<div class="intro"><div class="eyebrow">Your personal care workspace</div><div class="heading-row"><div><h1>${esc(title)}</h1><p>${esc(subtitle)}</p></div>${action}</div></div>`;
}
function empty(title, desc, action = "") {
  return `<div class="empty"><h3>${esc(title)}</h3><p>${esc(desc)}</p>${action}</div>`;
}
function route() {
  const [p, query = ""] = location.hash.slice(1).split("?");
  return { page: p || "today", params: new URLSearchParams(query) };
}
async function mutate(operation, message) {
  if (busy) throw Error("A save is still finishing. Please try again.");
  busy = true;
  const next = structuredClone(state);
  try {
    operation(next);
    await storage.save(next);
    state = next;
    if (message) toast(message);
    render();
    return true;
  } catch (e) {
    toast(e.message);
    throw e;
  } finally {
    busy = false;
  }
}
function form(title, body, submit, submitText = "Save") {
  modal.innerHTML = `<button class="close" data-action="close" aria-label="Close dialog">×</button><h2>${title}</h2><form>${body}<p class="form-error" role="alert"></p><div class="form-end">${button("Cancel", "close")}<button class="btn primary" type="submit">${submitText}</button></div></form>`;
  modal
    .querySelectorAll("button[data-action]")
    .forEach((b) => (b.type = "button"));
  modal.showModal();
  modal.querySelector("form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const el = e.currentTarget,
      submitBtn = el.querySelector("[type=submit]");
    if (submitBtn.disabled) return;
    submitBtn.disabled = true;
    el.querySelector(".form-error").textContent = "";
    try {
      await submit(new FormData(el), el);
      modal.close();
    } catch (err) {
      el.querySelector(".form-error").textContent = err.message;
    } finally {
      submitBtn.disabled = false;
    }
  });
}
function confirmAction(title, message, action) {
  form(esc(title), `<p>${esc(message)}</p>`, action, "Confirm");
}
function onboarding() {
  return `<main id="main" tabindex="-1" class="onboard"><a class="brand" href="#today"><img src="/icon.svg" alt="">CareInOne</a><div class="eyebrow" style="margin-top:38px">Your care, connected</div><h1>A clearer picture.<br>A little more peace of mind.</h1><p>Bring your records, questions, and next steps together.<br>Start with one small update. Make sense of it at your own pace.</p><div class="grid"><div class="card"><span class="badge">01 · Capture</span><h3 style="margin-top:14px">Keep the original</h3><p>A note, a visit summary, a question. Your own words are always there to return to.</p></div><div class="card"><span class="badge">02 · Make sense of it</span><h3 style="margin-top:14px">You're in control</h3><p>Review every proposed detail before it becomes part of your care picture.</p></div></div><div class="banner"><span><strong>On this browser, for you.</strong> Records stay in this browser profile. They do not sync to other devices. Clearing site data removes them. Save encrypted backups regularly. Anyone using this unlocked browser profile can access them.</span></div><div class="actions">${button("Start my workspace &nbsp; ↗", "start", "", "primary")}${button("Explore a fictional example", "demo")}${button("Restore a backup", "restore")}</div><p class="subtle" style="margin-top:18px">No account or payment required. Optional cloud analysis asks permission before sending source text.</p>${footer()}</main>`;
}
function render() {
  const { page, params } = route();
  document.title = `${paths[page] || "CareInOne"} · CareInOne`;
  if (!ready && !["privacy", "support"].includes(page)) {
    $("#app").innerHTML = onboarding();
    return;
  }
  const pending = state.claims.filter((c) => c.review === "pending").length;
  const contents = {
    today: today,
    care: () => care(params),
    sources: () => sources(params),
    review: () => reviewPage(params),
    tasks: taskPage,
    visits: visitPage,
    questions: questionPage,
    changes: activity,
    brief: briefPage,
    settings: settings,
    search: () => searchPage(params),
    trends: trendsPage,
    ask: () => askPage(params),
    evidence: evidencePage,
    privacy: privacy,
    support: support,
    licenses: licensesPage,
  };
  $("#app").innerHTML =
    `<div class="shell"><aside class="sidebar"><a href="#today" class="brand"><img src="/icon.svg" alt="">CareInOne</a><div class="eyebrow">Your workspace</div><nav class="nav" aria-label="Main navigation">${Object.entries(
      paths,
    )
      .map(
        ([k, v]) =>
          `<a href="#${k}" class="${page === k ? "active" : ""}" ${page === k ? 'aria-current="page"' : ""}>${svg(k)}${v}${k === "review" && pending ? `<span class="count">${pending}</span>` : ""}</a>`,
      )
      .join(
        "",
      )}</nav><div class="sidebottom"><div class="local-status"><i class="dot"></i>Saved on this browser</div><p>Your records stay with you.<br>Back up to keep them safe.</p><a class="subtle" href="#privacy">Your privacy matters ↗</a></div></aside><div class="workspace"><header class="topbar"><span class="crumb">My workspace &nbsp; / &nbsp; <strong>${esc(paths[page] || { search: "Search", trends: "Reported results", ask: "Ask your records", evidence: "Evidence map", privacy: "Privacy", support: "Help" }[page] || "Today")}</strong></span><div class="top-actions"><form class="search" id="search-form"><span aria-hidden="true">⌕</span><input name="q" placeholder="Search your care" aria-label="Search your care" maxlength="200" value="${page === "search" ? esc(params.get("q") || "") : ""}"></form><a class="avatar" href="#settings" aria-label="Profile settings">${esc((state.profile.name || "You").slice(0, 2).toUpperCase())}</a></div></header><main id="main" tabindex="-1">${state.demo ? `<div class="banner warning"><span>Fictional example workspace · These are synthetic records.</span>${button("Clear example", "clear-demo", "", "quiet")}</div>` : ""}${(contents[page] || today)()}${footer()}</main></div></div>`;
  $("#ask-form")?.addEventListener("submit", (e) => {
    e.preventDefault();
    location.hash = `ask?q=${encodeURIComponent(new FormData(e.currentTarget).get("q"))}`;
  });
  $("#search-form")?.addEventListener("submit", (e) => {
    e.preventDefault();
    location.hash = `search?q=${encodeURIComponent(new FormData(e.currentTarget).get("q"))}`;
  });
}
function today() {
  const entities = C.project(state),
    conflicts = entities.filter((x) => x.conflict),
    pending = state.claims.filter((c) => c.review === "pending"),
    open = C.tasks(state).filter((t) => t.status === "open");
  const upcoming = C.visits(state)
    .filter(
      (v) =>
        !v.paused && v.status !== "completed" && v.date && v.date >= C.day(),
    )
    .sort((a, b) => a.date.localeCompare(b.date))[0];
  const first = state.profile.name.trim().split(" ")[0];
  return `${heading(first ? `A little clarity, ${first}.` : "A little clarity for your day.", new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric", year: "numeric" }), button("+ Add an update", "capture", "", "primary"))}<section class="hero"><div><div class="eyebrow">One place for your next step</div><h2>Your care is a story.<br>Keep the pieces together.</h2><p>Save what happened, see what needs attention, and bring the right questions to your next conversation.</p><div class="actions">${button("Capture something new &nbsp; ↗", "capture", "", "primary")}${button("Record a voice note", "record")}</div></div><div class="hero-art" aria-hidden="true"><img src="/icon.svg" alt=""></div></section><div class="stats">${[
    [state.sources.length, "Saved sources", "▤"],
    [pending.length, "Ready to review", "✓"],
    [open.length, "Open next steps", "↗"],
    [conflicts.length, "To clarify", "◷"],
  ]
    .map(
      ([n, l, i]) =>
        `<div class="stat"><div class="stat-icon">${i}</div><div><strong>${n}</strong><span>${l}</span></div></div>`,
    )
    .join(
      "",
    )}</div><div class="columns"><section><div class="section-head"><h2>A little attention here</h2><a href="#tasks">All next steps ↗</a></div><div class="card">${conflicts
    .slice(0, 2)
    .map(
      (e) =>
        `<div class="item">${badge("Records differ", "amber")}<h3>${esc(e.label)} has different reported details</h3><p>Both sources are saved. Bring this to your care team to clarify.</p><a class="btn quiet" href="#care?entity=${encodeURIComponent(e.key)}">Compare the sources →</a></div>`,
    )
    .join(
      "",
    )}${pending.length ? `<div class="item">${badge("Your review")}<h3>${pending.length} proposed ${pending.length === 1 ? "detail is" : "details are"} waiting</h3><p>Check each detail against its original source.</p><a class="btn quiet" href="#review">Review details →</a></div>` : ""}${open
    .slice(0, 3)
    .map(
      (t) =>
        `<div class="item">${badge(t.dueDate ? "Check the date" : "Next step", "neutral")}<h3>${esc(t.title)}</h3><p>${esc(taskDue(t))}</p>${button("Make a little progress →", "edit-task", t.id, "quiet")}</div>`,
    )
    .join(
      "",
    )}${!conflicts.length && !pending.length && !open.length ? empty("Room for a fresh start", "Your next steps will appear here after you capture and review a source.", button("Add your first update", "capture", "", "primary")) : ""}</div></section><section><div class="section-head"><h2>Your next conversation</h2><a href="#visits">All visits ↗</a></div><div class="card">${upcoming ? `<div class="visit"><div class="date-tile"><span>${new Date(`${upcoming.date}T12:00:00`).toLocaleDateString(undefined, { month: "short" })}</span><strong>${upcoming.date.slice(8)}</strong></div><div><h3>${esc(upcoming.title)}</h3><p class="meta">${esc(upcoming.provider || "Provider not added")}<br>${esc(upcoming.time || "Time not provided")}</p></div></div><div class="quote">${esc(upcoming.agenda || "Add what matters most to you before this visit.")}</div>${button("Prepare for this visit →", "edit-visit", upcoming.id, "quiet")}` : empty("Make your next visit count", "Keep an agenda, your questions, and a recap together.", button("+ Plan a visit", "add-visit"))}</div><div class="section-head"><h2>Recently captured</h2><a href="#sources">All sources ↗</a></div><div class="card">${
    state.sources
      .slice(0, 3)
      .map(
        (s) =>
          `<div class="item"><span class="meta">${fmt(s.capturedAt)} · ${esc(s.kind)}</span><h3><a href="#sources?id=${encodeURIComponent(s.id)}">${esc(s.title)}</a></h3><p>${esc(s.text.slice(0, 95))}${s.text.length > 95 ? "…" : ""}</p></div>`,
      )
      .join("") ||
    `<p class="subtle">Your original notes and records will appear here.</p>`
  }</div></section></div>`;
}
function sources(params) {
  const src = state.sources.find((x) => x.id === params.get("id"));
  if (src)
    return `${heading(src.title, "Original evidence stays separate from the details you review.", `<a class="btn" href="#sources">← All sources</a>`)}<div class="card"><div class="heading-row"><span class="meta">Captured ${fmt(src.capturedAt)} · Event ${fmt(src.eventDate)} · ${esc(src.kind)}</span>${badge("Original preserved")}</div><div class="quote source-text">${esc(src.text)}</div>${src.attachment?.type?.startsWith("audio/") ? `<audio class="audio-player" controls preload="none" src="${esc(src.attachment.data)}"></audio>` : ""}${!src.text ? '<p class="subtle">Original captured without a transcript. No care statements have been inferred from it.</p>' : ""}${src.attachment ? button("Download original file", "attachment", src.id) : ""}<div class="actions"><a class="btn primary" href="#review?source=${encodeURIComponent(src.id)}">Review linked details</a>${button("Analyze with cloud", "analyze", src.id)}${button("Delete source", "delete-source", src.id, "danger")}</div><p class="subtle" style="margin-top:15px">Deleting this source also removes its proposals and linked tasks. This does not mean those tasks were medically completed.</p></div>${state.claims
      .filter((c) => c.sourceId === src.id)
      .map(
        (c) =>
          `<div class="card">${badge(c.review, c.review === "pending" ? "amber" : "neutral")}<h3 style="margin-top:10px">${esc(c.label)}</h3><span class="meta">${esc(C.kinds[c.kind])} · ${esc(c.certainty)} · ${esc(c.subject)}${c.page ? ` · Page ${c.page}` : ""}</span><div class="quote">${esc(c.quote)}</div>${button("Review or correct", "edit-claim", c.id, "small")}</div>`,
      )
      .join("")}`;
  return `${heading("The story, in your words.", "Every detail starts with an original source.", button("+ Add a source", "capture", "", "primary"))}${state.sources.length ? `<div class="grid">${state.sources.map((s) => `<article class="card">${badge(s.kind, "neutral")}<h2 style="margin-top:12px"><a href="#sources?id=${encodeURIComponent(s.id)}">${esc(s.title)}</a></h2><p class="meta">Event ${fmt(s.eventDate)} · Captured ${fmt(s.capturedAt)}</p><p>${esc(s.text.slice(0, 180))}${s.text.length > 180 ? "…" : ""}</p><div class="actions"><a class="btn small" href="#sources?id=${encodeURIComponent(s.id)}">Open source →</a><a class="btn quiet" href="#review?source=${encodeURIComponent(s.id)}">${state.claims.filter((c) => c.sourceId === s.id && c.review === "pending").length} to review</a></div></article>`).join("")}</div>` : `<div class="card">${empty("Start with what you have", "A quick note, a visit recap, or text from a record is enough.", button("Capture a source", "capture", "", "primary"))}</div>`}`;
}
function reviewPage(params) {
  const sourceId = params.get("source"),
    show = params.get("show") || "pending";
  const claims = state.claims.filter(
    (c) =>
      (!sourceId || c.sourceId === sourceId) &&
      (show === "all" || c.review === show),
  );
  return `${heading("A moment to make it yours.", "Check the source. Correct the detail. Then decide what to keep.")}<div class="filters">${["pending", "accepted", "rejected", "all"].map((k) => `<a class="${show === k ? "active" : ""}" href="#review?show=${k}${sourceId ? `&source=${encodeURIComponent(sourceId)}` : ""}">${{ pending: "Needs review", accepted: "Accepted", rejected: "Rejected", all: "All details" }[k]}</a>`).join("")}</div>${
    claims
      .map((c) => {
        const src = state.sources.find((s) => s.id === c.sourceId);
        return `<article class="card"><div class="heading-row"><div>${badge(C.kinds[c.kind])} ${badge(c.review, "neutral")} ${c.subject !== "patient" ? badge(`${c.subject} attribution`, "amber") : ""} ${c.negated ? badge("Negated", "amber") : ""} ${c.conditional ? badge("Conditional", "amber") : ""}</div><span class="meta">${esc(c.certainty)}</span></div><h2 style="margin:15px 0 6px">${esc(c.label)}</h2><p>${esc([c.value, c.frequency, c.action].filter(Boolean).join(" · "))}</p><div class="quote">“${esc(c.quote)}”</div><a class="meta" href="#sources?id=${encodeURIComponent(src.id)}">${esc(src.title)} ↗</a>${c.clarification ? `<p style="margin-top:12px">Clarify: ${esc(c.clarification)}</p>` : ""}<details class="review-details"><summary>How this detail is used</summary><p>Accepting means you reviewed this reported statement. Conditional, negated, uncertain, historical, and non-patient statements remain saved evidence and are excluded from the current care picture. Conflicting accepted records remain visible together.</p><p class="meta">${esc(c.extraction)}${c.page ? ` · Page ${c.page}` : ""} · Event ${fmt(c.eventDate)} · Due ${fmt(c.dueDate)}</p></details><div class="actions">${button("Accept detail", "accept", c.id, "primary")}${button("Edit first", "edit-claim", c.id)}${button("Reject", "reject", c.id)}</div></article>`;
      })
      .join("") ||
    `<div class="card">${empty("Nothing waiting here", "Your sources are safe. New proposed details will appear after you capture a source.", button("Add an update", "capture"))}</div>`
  }`;
}
function care(params) {
  const entities = C.project(state),
    selected = params.get("entity"),
    category = params.get("category") || "all";
  let shown = entities.filter(
    (e) =>
      (!selected || e.key === selected) &&
      (category === "all" || e.kind === category),
  );
  return `${heading("Your care, brought together.", "Reviewed statements with a path back to the original evidence.")}<div class="filters"><a href="#trends">Reported results ↗</a><a href="#ask">Ask your records ↗</a><a href="#evidence">Evidence map ↗</a></div><div class="filters"><a class="${category === "all" ? "active" : ""}" href="#care">Everything</a>${[...new Set(entities.map((e) => e.kind))].map((k) => `<a class="${category === k ? "active" : ""}" href="#care?category=${k}">${esc(C.kinds[k])}</a>`).join("")}</div>${
    shown
      .map(
        (e) =>
          `<article class="card"><div class="heading-row"><div>${badge(C.kinds[e.kind])}<h2 style="margin:10px 0 0">${esc(e.label)}</h2></div>${badge(e.status, e.conflict ? "amber" : "neutral")}</div>${e.conflict ? `<p style="margin-top:12px">These records report different details. No clinical winner has been chosen. Ask your care team to clarify.</p>` : ""}${e.claims
            .map((c) => {
              const src = state.sources.find((s) => s.id === c.sourceId);
              return `<div class="item"><h3>${esc([c.value, c.frequency, c.action].filter(Boolean).join(" · "))}</h3><div class="quote">“${esc(c.quote)}”</div><a class="meta" href="#sources?id=${encodeURIComponent(src.id)}">${esc(src.title)} · Event ${fmt(c.eventDate)} ↗</a><div class="actions">${button("Correct review", "edit-claim", c.id, "small")}</div></div>`;
            })
            .join(
              "",
            )}${e.conflict ? button("Save a clarification question", "conflict-question", e.key, "quiet") : ""}</article>`,
      )
      .join("") ||
    `<div class="card">${empty("Your care picture starts with review", "Accept a source-linked detail to see it here. Uncertain and historical statements stay with their source.", `<a class="btn primary" href="#review">Review details</a>`)}</div>`
  }`;
}
function taskDue(t) {
  if (t.paused)
    return "Paused: the supporting statement needs review. Your saved notes and outreach remain available.";
  if (!t.dueDate)
    return "No due date provided. You can set a personal check-back date.";
  return `${t.duePrecision === "exact" ? "Due" : t.duePrecision === "approximate" ? "Approximate date" : "Recorded date (precision unknown)"} ${fmt(t.dueDate)}${t.duePrecision === "exact" && t.dueDate < C.day() && t.status === "open" ? " · Date has passed; confirm status with your care team." : ""}`;
}
function taskPage() {
  const all = C.tasks(state).sort(
    (a, b) =>
      (a.status === "open" ? 0 : 1) - (b.status === "open" ? 0 : 1) ||
      (a.dueDate || "9999").localeCompare(b.dueDate || "9999"),
  );
  return `${heading("Small steps. Less loose ends.", "Keep track of the practical work between appointments.", button("+ Add a next step", "add-task", "", "primary"))}${
    all
      .map((t) => {
        const c = state.claims.find((c) => c.id === t.claimId);
        return `<div class="card"><div class="heading-row"><h2 style="margin:0">${esc(t.title)}</h2>${badge(t.status, t.status === "open" ? "amber" : "neutral")}</div><p class="meta" style="margin-top:9px">${esc(taskDue(t))}</p>${t.notes ? `<p class="source-text">${esc(t.notes)}</p>` : ""}${c ? `<a class="meta" href="#sources?id=${encodeURIComponent(c.sourceId)}">View supporting source ↗</a>` : badge("Personal reminder", "neutral")}${t.outreach.length ? `<details><summary class="subtle">${t.outreach.length} saved outreach ${t.outreach.length === 1 ? "note" : "notes"}</summary>${t.outreach.map((o) => `<div class="quote">${esc(o.text)}<br><span class="meta">${fmt(o.at)}</span></div>`).join("")}</details>` : ""}<div class="actions">${button("Edit / update status", "edit-task", t.id)}${!t.paused ? button("Help me follow through", "outreach", t.id) : ""}${t.dueDate && !t.paused ? button("Add to calendar", "task-calendar", t.id) : ""}</div></div>`;
      })
      .join("") ||
    `<div class="card">${empty("A little room to breathe", "Reviewed referrals, requested tests, and follow-ups will appear here. You can add a personal next step too.", button("Add a next step", "add-task"))}</div>`
  }`;
}
function visitPage() {
  return `${heading("Make space for what matters.", "Prepare for a visit. Capture what you heard. Keep the thread.", button("+ Plan a visit", "add-visit", "", "primary"))}${
    C.visits(state)
      .slice()
      .sort((a, b) => a.date.localeCompare(b.date))
      .map(
        (v) =>
          `<article class="card"><div class="heading-row"><div><span class="meta">${fmt(v.date)}${v.time ? ` · ${esc(v.time)}` : ""}</span><h2 style="margin:5px 0">${esc(v.title)}</h2><span class="meta">${esc(v.provider || "Provider not provided")}</span></div>${badge(v.status, "neutral")}</div>${v.claimId ? `<p class="subtle">From a reviewed appointment statement. <a href="#sources?id=${encodeURIComponent(state.claims.find((c) => c.id === v.claimId)?.sourceId || "")}">Supporting source ↗</a>${v.paused ? " · Paused because its supporting statement needs review." : ""}</p>` : ""}<div class="quote">${esc(v.agenda || "What would you like to talk about?")}</div>${v.recap ? `<h3>What I heard</h3><p class="source-text">${esc(v.recap)}</p>` : ""}<div class="actions">${button("Prepare / edit / recap", "edit-visit", v.id)}${v.date && !v.paused ? button("Calendar file", "visit-calendar", v.id) : ""}${v.recap ? button("Save recap as a source", "recap-source", v.id, "primary") : ""}${button("Remove visit", "delete-visit", v.id, "danger small")}</div></article>`,
      )
      .join("") ||
    `<div class="card">${empty("Your next conversation starts here", "An agenda and a few questions can make an appointment feel more manageable.", button("Plan a visit", "add-visit"))}</div>`
  }`;
}
function questionPage() {
  return `${heading("Keep the questions close.", "A place for the things you want to ask, whenever they come to mind.", button("+ Add a question", "add-question", "", "primary"))}<div class="card">${state.questions.map((q) => `<div class="item"><div class="heading-row"><h3>${esc(q.text)}</h3>${badge(q.done ? "Discussed" : "To ask", q.done ? "neutral" : "amber")}</div><div class="actions">${button(q.done ? "Reopen" : "Mark discussed", "toggle-question", q.id, "small")}${button("Remove", "delete-question", q.id, "small")}</div></div>`).join("") || empty("There is no small question", "Save what is on your mind before your next conversation.", button("Add a question", "add-question"))}</div>`;
}
function activity() {
  return `${heading("A record of your progress.", "Your capture and review history, in order.")}<div class="card"><div class="log">${
    state.history
      .slice(0, 200)
      .map(
        (h) =>
          `<div class="item"><span class="meta">${fmt(h.at)}</span><h3>${esc(h.action)}</h3><p>${esc(h.label)}</p></div>`,
      )
      .join("") ||
    empty(
      "Your story starts here",
      "Captures, reviews, and changes will leave a clear trail.",
    )
  }</div></div>`;
}
function briefPage() {
  return `${heading("A clearer conversation starter.", "Reviewed care, open next steps, and the questions you want to ask.", button("Print / save PDF", "print", "", "primary"))}<div class="banner no-print"><span>This brief contains personal health information. Review it before sharing.</span>${button("Download text", "download-brief", "", "quiet")}</div><article class="card"><pre class="pre-brief">${esc(C.brief(state))}</pre></article>`;
}
function searchPage(params) {
  const q = (params.get("q") || "").trim().toLowerCase();
  const src = q
      ? state.sources.filter((s) =>
          `${s.title} ${s.text}`.toLowerCase().includes(q),
        )
      : [],
    claims = q
      ? state.claims.filter((c) =>
          `${c.label} ${c.value} ${c.quote}`.toLowerCase().includes(q),
        )
      : [];
  return `${heading("Find a piece of the story.", q ? `Results for “${params.get("q")}”` : "Use the search box to find saved words and details.")}<div class="card"><h2>Sources</h2>${src.map((s) => `<div class="item"><a href="#sources?id=${encodeURIComponent(s.id)}">${esc(s.title)} ↗</a><p>${esc(s.text.slice(0, 170))}</p></div>`).join("") || '<p class="subtle">No matching sources.</p>'}</div><div class="card"><h2>Reported details</h2>${claims.map((c) => `<div class="item"><h3>${esc(c.label)} ${badge(c.review, "neutral")}</h3><p>${esc(c.quote)}</p><a class="meta" href="#sources?id=${encodeURIComponent(c.sourceId)}">Open supporting source ↗</a></div>`).join("") || '<p class="subtle">No matching details.</p>'}</div>`;
}
function trendsPage() {
  const groups = trends(state);
  return `${heading("Numbers, with their context.", "Reported results grouped by exact label and unit. No clinical interpretation.")}<div class="filters"><a href="#care">← My care</a></div>${
    groups
      .map((g) => {
        const points = g.points.filter((p) => p.date),
          values = points.map((p) => p.value),
          lo = Math.min(...values),
          hi = Math.max(...values),
          span = hi - lo || Math.max(Math.abs(hi) * 0.1, 1),
          low = lo - span * 0.15,
          high = hi + span * 0.15;
        const first = points[0]?.date,
          last = points[points.length - 1]?.date,
          range = Date.parse(last) - Date.parse(first);
        const position = (p) => ({
          x:
            45 +
            (range ? (Date.parse(p.date) - Date.parse(first)) / range : 0.5) *
              480,
          y: 155 - ((p.value - low) / (high - low)) * 125,
        });
        return `<article class="card"><h2>${esc(g.label)} ${badge(g.unit || "Unit not reported", "neutral")}</h2>${
          points.length >= 2
            ? `<svg viewBox="0 0 580 195" role="img" aria-label="Reported ${esc(g.label)} over time. Exact values and sources follow in the table."><path d="M45 20V155H540" fill="none" stroke="#d2deca"/><polyline points="${points
                .map((p) => {
                  const q = position(p);
                  return `${q.x},${q.y}`;
                })
                .join(
                  " ",
                )}" fill="none" stroke="#39765b" stroke-width="2"/>${points
                .map((p) => {
                  const q = position(p);
                  return `<circle cx="${q.x}" cy="${q.y}" r="4" fill="#39765b"><title>${esc(p.date)}: ${p.value} ${esc(g.unit)}</title></circle>`;
                })
                .join(
                  "",
                )}<text x="45" y="182" font-size="11" fill="#66766c">${esc(first)}</text><text x="455" y="182" font-size="11" fill="#66766c">${esc(last)}</text></svg><p class="subtle">Vertical scale follows the reported values and may not start at zero. Connecting lines only organize observations; they do not imply continuous measurement.</p>`
            : '<p class="subtle">Two dated measurements are needed for a chart. Undated values stay in the table.</p>'
        }<div class="table-wrap"><table><thead><tr><th>Event date</th><th>Reported value</th><th>Original evidence</th></tr></thead><tbody>${g.points.map((p) => `<tr><td>${fmt(p.date)}</td><td>${p.value} ${esc(g.unit)}</td><td><a href="#sources?id=${encodeURIComponent(p.sourceId)}">${esc(state.sources.find((s) => s.id === p.sourceId)?.title)} ↗</a><br><span class="meta">${esc(p.quote)}</span></td></tr>`).join("")}</tbody></table></div></article>`;
      })
      .join("") ||
    `<div class="card">${empty("The context comes first", "Import a supported numeric FHIR observation, or capture a line such as “Result: Glucose = 95 mg/dL” with its event date. Review it before it appears here.")}</div>`
  }`;
}
function askPage(params) {
  const q = params.get("q") || "",
    results = q ? ask(state, q) : [];
  return `${heading("Ask what your records say.", "Find exact saved statements. This does not provide medical advice or infer an answer.")}<div class="filters"><a href="#care">← My care</a></div><div class="card"><form id="ask-form"><label>Your question<input name="q" value="${esc(q)}" maxlength="300" placeholder="e.g. What do my notes say about lisinopril?" required></label><button class="btn primary" type="submit">Find supporting records</button></form></div>${q ? `<p class="subtle">${results.length ? "Matching statements follow with their review status. Check the source and attribution." : "No matching statements were found. This does not mean the event did not happen or the information is absent from records not yet captured."}</p>` : ""}${results.map((c) => `<div class="card">${badge(c.review, c.review === "accepted" ? "neutral" : "amber")} ${badge(c.certainty, "neutral")} ${badge(c.subject, "neutral")}<h3 style="margin-top:12px">${esc(c.label)}</h3><div class="quote">“${esc(c.quote)}”</div><a href="#sources?id=${encodeURIComponent(c.sourceId)}">${esc(state.sources.find((s) => s.id === c.sourceId)?.title)} ↗</a></div>`).join("")}`;
}
function evidencePage() {
  return `${heading("Every detail has a beginning.", "Trace saved sources to their proposed and reviewed statements.")}<div class="filters"><a href="#care">← My care</a></div>${
    evidenceMap(state)
      .map(
        ({ source, claims }) =>
          `<div class="card"><h2><a href="#sources?id=${encodeURIComponent(source.id)}">${esc(source.title)} ↗</a></h2><p class="meta">Captured ${fmt(source.capturedAt)} · Event ${fmt(source.eventDate)}</p><ul class="evidence-list">${claims.map((c) => `<li>${badge(c.review, c.review === "pending" ? "amber" : "neutral")} <strong>${esc(c.label)}</strong> <span class="meta">${esc(C.kinds[c.kind])}${c.page ? ` · Page ${c.page}` : ""}</span><div class="subtle">${esc(c.quote)}</div></li>`).join("") || "<li>Original preserved. No proposed statements.</li>"}</ul></div>`,
      )
      .join("") ||
    `<div class="card">${empty("No source links yet", "Capture your first source to begin the evidence map.")}</div>`
  }`;
}
function settings() {
  return `${heading("A workspace that feels like yours.", "Your profile, privacy, backup, and optional cloud connection.")}<div class="grid"><section class="card"><h2>A little about you</h2><h3>${esc(state.profile.name || "Your name is not added")}</h3><p>${esc(state.profile.priorities || "Add what matters most to you. This is optional.")}</p>${button("Edit profile", "profile")}</section><section class="card"><h2>Keep a safe copy</h2><p>Records stay in this browser profile. Export an encrypted backup before clearing data, changing devices, or using a different domain. There is no automatic sync.</p><div class="actions">${button("Encrypted backup", "backup", "", "primary")}${button("Restore a backup", "restore")}</div><p class="subtle" style="margin-top:12px">Keep the passphrase somewhere safe. We cannot recover it.</p></section><section class="card"><h2>Optional cloud analysis</h2><p>Local capture and review work without a connection. Cloud analysis sends only the selected source text through the CareInOne gateway to its disclosed model providers.</p><div class="actions">${button("Connection & consent", "cloud")}${button("Disconnect", "disconnect")}</div><p class="subtle" style="margin-top:12px">AI analysis has a daily allowance. Local records stay available if the allowance is used up. Provider API keys are never entered here.</p></section><section class="card"><h2>This browser</h2><p>${state.sources.length} sources · ${state.claims.length} proposed details · ${state.visits.length} visits</p><p class="subtle">Stored in IndexedDB. This browser vault is not encrypted at rest by this website. Use your own locked device and a separate browser profile.</p><div class="actions">${button("Request persistent storage", "persist")}${button("Clear this workspace", "clear", "", "danger")}</div></section></div>`;
}
function privacy() {
  return `${heading("Your privacy, in plain language.", "CareInOne Web · Updated October 25, 2026")}<article class="card legal"><h2>Records stay in this browser</h2><p>Source text, attachments, reviewed details, profile, visits, questions, and history are stored in this browser profile using IndexedDB. There are no patient accounts or automatic device synchronization. Closing the tab does not erase your data. Clearing site data, private browsing, eviction, switching domains, or losing your device can remove access. Anyone using this unlocked browser profile can open your workspace. The website does not encrypt the browser vault at rest.</p><h2>Backups you control</h2><p>Backup files are encrypted in your browser with AES-256-GCM and a key derived from your passphrase using PBKDF2-SHA-256 (600,000 iterations). The operator cannot recover the passphrase. A restored backup replaces the current browser workspace only after confirmation. Printed/PDF and text care briefs are unencrypted and contain the selected health information.</p><h2>Optional analysis</h2><p>Cloud analysis is optional. Before the selected source text leaves the browser, you see the configured provider/model recipients and explicitly consent. The website server forwards the text to the existing CareInOne model gateway. That gateway does not store patient content. Model providers and infrastructure may have their own retention policies; the connection screen shows the configured recipients. An unsuccessful request may still have reached a provider. Server credentials never appear in browser code. Cloud access cookies are HttpOnly, SameSite=Strict, and Secure on public HTTPS deployments.</p><h2>Website operation</h2><p>The hosting provider receives connection metadata such as IP address and request timing. Application access logs are disabled in the supplied start command; hosting-level logs are governed by the hosting provider. Public AI access uses signed anonymous sessions and daily allowances. The server keeps temporary anonymous session identifiers and rate-limit counts in memory. Public analysis sessions last up to one day and have a daily allowance, alongside a site-wide allowance. These identifiers are separate from browser records. This site uses no analytics, advertising scripts, or third-party fonts.</p><h2>Your choices</h2><p>You can inspect or delete individual sources, reject proposed details, disconnect analysis, export a backup, or clear the entire local workspace in Settings. Deleting local data cannot retract information already shared or sent to a provider.</p><h2>Contact and scope</h2><p><a href="https://careinone-api.onrender.com/support" target="_blank" rel="noopener noreferrer">Contact CareInOne support</a>. CareInOne organizes information you report; it does not diagnose, prescribe, provide triage, or monitor emergencies.</p></article>`;
}
function licensesPage() {
  return `${heading("Open-source notices.", "The components used to read documents locally in this browser.")}<article class="card legal"><h2>PDF.js 5.5.207</h2><p>Mozilla and contributors. Apache License 2.0. <a href="/vendor/pdf-5.5.207/LICENSE" target="_blank" rel="noopener noreferrer">License text</a>.</p><h2>Tesseract.js and core 7.0.0</h2><p>Naptha, Tesseract and contributors. <a href="/vendor/ocr-7.0.0/LICENSE" target="_blank" rel="noopener noreferrer">Tesseract.js license</a> · <a href="/vendor/ocr-7.0.0/core/LICENSE" target="_blank" rel="noopener noreferrer">Core license</a>.</p><h2>English recognition data</h2><p>Tesseract OCR contributors; the @tesseract.js-data/eng 1.0.0 package supplies the English trained data. It is processed locally. Additional PDF font notices accompany their files under the bundled standard-font directory.</p></article>`;
}
function support() {
  return `${heading("A little help, when you need it.", "Practical answers for your CareInOne web workspace.")}<div class="card legal"><h2>Start small</h2><p>Choose Add an update, paste a note or visit recap, and save. Open Review, read each original quotation, and accept, edit, or reject each proposed detail. Only accepted statements with suitable attribution appear in My care.</p><h2>Keep a backup</h2><p>Settings → Encrypted backup downloads a passphrase-protected file. Use Restore a backup on another device or domain. Moving from localhost to your purchased domain requires a backup and restore; browsers isolate each website's storage.</p><h2>Documents and recordings</h2><p>Import TXT, native-text PDFs, scanned PDFs and images, or the supported FHIR JSON subset. PDF parsing and English OCR run in this browser using self-hosted libraries. Check extracted names, numbers and units carefully. Voice notes can be recorded locally with explicit permission, paused, played, downloaded and deleted. Recording stops when the tab is hidden. Automatic speech transcription is not included; type or paste a transcript for review.</p><h2>Dates and differences</h2><p>Capture dates and event dates stay separate. Missing dates are not guessed. Different reported medication details are shown together for clarification. Accepting a proposal confirms your review, not its clinical correctness.</p><h2>Connection trouble</h2><p>Local workflows continue if the model service is unavailable. Public AI connects without an account or access code and asks consent for each selected source. Daily allowances apply; if exhausted or unavailable, local capture/review and backups still work. Renew consent after recipient changes. No provider key belongs in the website. Only the selected source text is sent; original files remain in your browser.</p><h2>Contact</h2><p><a href="https://careinone-api.onrender.com/support" target="_blank" rel="noopener noreferrer">CareInOne support and contact details ↗</a></p><p><a href="#licenses">Open-source notices</a></p></div>`;
}
function captureForm() {
  let imported = null,
    processing = false;
  const controller = new AbortController();
  form(
    "Save a piece of your story",
    `<p>Start with a note or import a record. PDF text and English image OCR are processed in your browser. Review every proposed detail.</p><label>Source title<input name="title" maxlength="200" placeholder="e.g. My appointment recap" required></label><div class="form-row"><label>Source type<select name="kind"><option value="typed">Personal note</option><option value="manual">Structured / manual entry</option><option value="textFile">Text file</option><option value="pdf">PDF</option><option value="photo">Photo / image</option><option value="fhir">FHIR JSON</option><option value="visitRecording">Visit transcript</option></select></label><label>When did it happen? (optional)<input name="eventDate" type="date"><span class="subtle">Leave blank if unknown.</span></label></div><label>Import TXT, PDF, image, or FHIR JSON<input name="file" type="file" accept=".txt,.json,text/plain,application/json,application/pdf,image/png,image/jpeg,image/webp"></label><p class="subtle">Files up to 5 MB · PDFs up to 50 pages / 10 scanned pages · English OCR. Original files stay on this browser. OCR can misread names, numbers and units.</p><p id="import-progress" class="subtle" role="status"></p><label>Text to review<textarea name="text" maxlength="200000" rows="7" placeholder="What happened? What were you told? What would you like to remember?"></textarea></label>`,
    async (f) => {
      if (processing)
        throw Error(
          "Wait for document processing to finish, or cancel and paste its text.",
        );
      const file = f.get("file");
      let attachment = null;
      if (file?.size) {
        if (file.size > 5 * 1024 * 1024)
          throw Error("Choose a file smaller than 5 MB.");
        if (
          ![
            "text/plain",
            "application/pdf",
            "application/json",
            "image/png",
            "image/jpeg",
            "image/webp",
            "",
          ].includes(file.type)
        )
          throw Error("Unsupported file type.");
        if (
          file.type !== "text/plain" &&
          !file.name.toLowerCase().endsWith(".txt")
        ) {
          const type = file.name.toLowerCase().endsWith(".json")
            ? "application/json"
            : file.type;
          if (
            ![
              "application/pdf",
              "application/json",
              "image/png",
              "image/jpeg",
              "image/webp",
            ].includes(type)
          )
            throw Error("Unsupported file type.");
          attachment = {
            name: file.name,
            type,
            data: await dataURL(new Blob([file], { type })),
          };
        }
      }
      const text = f.get("text");
      if (!text.trim() && !attachment)
        throw Error("Enter some text or attach an original file.");
      const unchanged = imported && text === imported.text;
      await mutate(
        (s) =>
          C.addSource(
            s,
            {
              title: f.get("title"),
              kind: f.get("kind"),
              eventDate: f.get("eventDate"),
              text,
              attachment,
              pages: unchanged ? imported.pages : [],
            },
            unchanged ? imported.proposals : null,
          ),
        "Source saved. Review its proposed details.",
      );
      location.hash = "review";
    },
    "Save & review",
  );
  modal.addEventListener("close", () => controller.abort(), { once: true });
  modal.querySelector("[name=file]").addEventListener("change", async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const form = modal.querySelector("form"),
      text = form.querySelector("[name=text]"),
      status = form.querySelector("#import-progress"),
      save = form.querySelector("[type=submit]");
    if (
      text.value.trim() &&
      !confirm("Replace the current unsaved text with this imported document?")
    ) {
      e.target.value = "";
      return;
    }
    processing = true;
    save.disabled = true;
    imported = null;
    status.textContent = "Opening your document locally…";
    if (!form.querySelector("[name=title]").value)
      form.querySelector("[name=title]").value = file.name;
    try {
      imported = await importDocument(file, {
        signal: controller.signal,
        onProgress: (message) => (status.textContent = message),
      });
      text.value = imported.text;
      form.querySelector("[name=kind]").value = imported.kind;
      status.textContent =
        imported.notice ||
        `Prepared ${imported.pages.length || 1} ${imported.pages.length === 1 ? "page" : "pages"}. Check the text against the original before saving.`;
    } catch (err) {
      if (err.name !== "AbortError")
        status.textContent = `${err.message} You can paste the relevant text or save the original for later.`;
    } finally {
      processing = false;
      save.disabled = false;
    }
  });
}
function recordForm() {
  let recorder = null,
    audio = null,
    previewURL = null,
    closed = false;
  form(
    "A voice note, kept with you",
    `<p>Audio is recorded only after you start. It stays in this browser. If anyone else is present, get their permission before recording. Recording stops when you leave this tab.</p><label>Source title<input name="title" required maxlength="200" placeholder="e.g. A thought after my visit"></label><label class="checkline"><input name="recordingConsent" type="checkbox"><span>I have permission to record and want to capture audio locally.</span></label><div class="actions"><button type="button" class="btn primary" id="record-start">Start recording</button><button type="button" class="btn" id="record-pause" disabled>Pause</button><button type="button" class="btn" id="record-stop" disabled>Stop</button></div><p id="record-status" role="status" class="subtle">Not recording · Maximum 10 minutes / 15 MB.</p><audio id="record-preview" class="audio-player" controls hidden></audio><label>Transcript / what I want to remember (optional)<textarea name="text" maxlength="40000" placeholder="Type or paste a transcript. Speech transcription is not sent to an external service."></textarea></label><p class="subtle">Only transcript text becomes reviewable proposals. Audio alone never becomes an inferred care statement.</p>`,
    async (f) => {
      if (!audio) throw Error("Start and stop a recording before saving.");
      if (recorder?.recorder?.state !== "inactive")
        throw Error("Stop the recording first.");
      const type = audio.type || "audio/webm",
        extension = type.includes("mp4")
          ? "m4a"
          : type.includes("ogg")
            ? "ogg"
            : "webm";
      const attachment = {
        name: `careinone-voice-${C.day()}.${extension}`,
        type,
        data: await dataURL(audio),
      };
      await mutate(
        (s) =>
          C.addSource(s, {
            title: f.get("title"),
            kind: "voice",
            text: f.get("text"),
            attachment,
          }),
        "Voice source saved on this browser.",
      );
      location.hash = "sources";
    },
    "Save voice source",
  );
  const start = modal.querySelector("#record-start"),
    pause = modal.querySelector("#record-pause"),
    stop = modal.querySelector("#record-stop"),
    status = modal.querySelector("#record-status"),
    preview = modal.querySelector("#record-preview");
  start.addEventListener("click", async () => {
    if (!modal.querySelector("[name=recordingConsent]").checked) {
      status.textContent = "Confirm recording permission before starting.";
      return;
    }
    start.disabled = true;
    recorder = new LocalRecorder({
      onState: (phase, seconds) => {
        if (closed) return;
        status.textContent = `${phase === "recording" ? "● Recording" : phase === "paused" ? "Paused" : "Stopped"} · ${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
        pause.textContent = phase === "paused" ? "Resume" : "Pause";
        pause.disabled = stop.disabled = phase === "stopped";
      },
      onStop: (blob) => {
        if (closed) return;
        if (!blob.size) {
          status.textContent =
            "No audio was captured. Cancel and try again, or use a typed note.";
          return;
        }
        audio = blob;
        previewURL = URL.createObjectURL(blob);
        preview.src = previewURL;
        preview.hidden = false;
      },
    });
    try {
      await recorder.start();
      if (closed) {
        recorder.stop();
        return;
      }
      pause.disabled = stop.disabled = false;
    } catch (err) {
      status.textContent =
        err.name === "NotAllowedError"
          ? "Microphone permission was not granted. Use a typed note instead."
          : err.message;
      start.disabled = false;
    }
  });
  pause.addEventListener("click", () =>
    recorder?.recorder?.state === "paused"
      ? recorder.resume()
      : recorder.pause(),
  );
  stop.addEventListener("click", () => recorder?.stop());
  modal.addEventListener(
    "close",
    () => {
      closed = true;
      recorder?.stop();
      if (previewURL) URL.revokeObjectURL(previewURL);
    },
    { once: true },
  );
}
function editClaim(claimId) {
  const c = state.claims.find((x) => x.id === claimId);
  form(
    "Review the reported detail",
    `<div class="quote">“${esc(c.quote)}”</div><label>Label<input name="label" value="${esc(c.label)}" maxlength="200" required></label><div class="form-row"><label>Category<select name="kind">${Object.entries(
      C.kinds,
    )
      .map(
        ([k, v]) =>
          `<option value="${k}" ${k === c.kind ? "selected" : ""}>${v}</option>`,
      )
      .join(
        "",
      )}</select></label><label>Reported value / dose<input name="value" value="${esc(c.value)}" maxlength="4000"></label></div><label>Frequency<input name="frequency" value="${esc(c.frequency)}" maxlength="200"></label><div class="form-row"><label>Attribution<select name="subject">${["patient", "family", "other", "unknown"].map((k) => `<option ${c.subject === k ? "selected" : ""}>${k}</option>`).join("")}</select></label><label>Certainty<select name="certainty">${["reported", "documented", "uncertain", "conditional", "historical", "disputed", "superseded", "unknown"].map((k) => `<option ${c.certainty === k ? "selected" : ""}>${k}</option>`).join("")}</select></label></div><div class="form-row"><label>Due date (optional)<input name="dueDate" type="date" value="${esc(c.dueDate)}"></label><label>Date precision<select name="duePrecision">${["unknown", "exact", "approximate"].map((k) => `<option ${c.duePrecision === k ? "selected" : ""}>${k}</option>`).join("")}</select></label></div><label>Review decision<select name="review"><option value="accepted" ${c.review === "accepted" ? "selected" : ""}>Accept as reviewed</option><option value="pending" ${c.review === "pending" ? "selected" : ""}>Keep pending</option><option value="rejected" ${c.review === "rejected" ? "selected" : ""}>Reject</option></select></label><p>Edits are your correction of the reported detail. The original quote, action, and conditional / negative attribution remain preserved.</p>`,
    async (f) => {
      const edits = Object.fromEntries(f);
      await mutate(
        (s) => C.review(s, claimId, f.get("review"), edits),
        "Review saved.",
      );
    },
  );
}
function editTask(taskId) {
  const t = C.tasks(state).find((t) => t.id === taskId) || {
    title: "",
    dueDate: "",
    status: "open",
    notes: "",
    duePrecision: "exact",
  };
  form(
    taskId ? "A little progress on this step" : "Add a personal next step",
    `<label>Next step<input name="title" value="${esc(t.title)}" maxlength="200" required></label><div class="form-row"><label>Personal check-back date<input name="dueDate" type="date" value="${esc(t.dueDate)}"></label><label>Date precision<select name="duePrecision"><option value="exact" ${t.duePrecision === "exact" ? "selected" : ""}>Exact / personal date</option><option value="approximate" ${t.duePrecision === "approximate" ? "selected" : ""}>Approximate</option><option value="unknown" ${t.duePrecision === "unknown" ? "selected" : ""}>Unknown</option></select></label></div><label>Status<select name="status"><option value="open" ${t.status === "open" ? "selected" : ""}>Open</option><option value="completed" ${t.status === "completed" ? "selected" : ""}>Completed — my report</option><option value="dismissed" ${t.status === "dismissed" ? "selected" : ""}>Dismissed — no completion claim</option></select></label><label>My notes<textarea name="notes" maxlength="10000">${esc(t.notes)}</textarea></label><p>A personal check-back date is your reminder, not a medical deadline. Completion is recorded as your report.</p>`,
    async (f) => {
      await mutate((s) => {
        const patch = Object.fromEntries(f);
        if (taskId) C.updateTask(s, taskId, patch);
        else {
          s.tasks.push({ id: C.id(), ...patch, outreach: [] });
          C.audit(s, "Personal next step added", patch.title);
        }
      }, "Next step saved.");
    },
  );
}
function editVisit(visitId) {
  const v = C.visits(state).find((v) => v.id === visitId) || {
    title: "",
    date: "",
    time: "",
    provider: "",
    agenda: "",
    recap: "",
    status: "planned",
  };
  form(
    visitId ? "Make the most of your visit" : "Plan a conversation",
    `<label>Visit title<input name="title" value="${esc(v.title)}" required maxlength="200" placeholder="e.g. Primary care check-in"></label><div class="form-row"><label>Date<input name="date" type="date" value="${esc(v.date)}" required></label><label>Time (optional)<input name="time" type="time" value="${esc(v.time)}"></label></div><label>Care team / location<input name="provider" value="${esc(v.provider)}" maxlength="300"></label><label>What matters most? My agenda<textarea name="agenda" maxlength="10000">${esc(v.agenda)}</textarea></label><details><summary>My saved questions (${state.questions.filter((q) => !q.done).length})</summary><ul>${state.questions
      .filter((q) => !q.done)
      .map((q) => `<li>${esc(q.text)}</li>`)
      .join(
        "",
      )}</ul></details><label>After the visit: what I heard<textarea name="recap" maxlength="40000">${esc(v.recap)}</textarea></label><label>Status<select name="status"><option value="planned" ${v.status === "planned" ? "selected" : ""}>Planned</option><option value="completed" ${v.status === "completed" ? "selected" : ""}>Visit happened — my report</option></select></label>`,
    async (f) => {
      const patch = Object.fromEntries(f);
      if (!C.validDate(patch.date)) throw Error("Choose a valid date.");
      await mutate((s) => {
        if (visitId) C.updateVisit(s, visitId, patch);
        else s.visits.push({ id: C.id(), ...patch });
        C.audit(s, "Visit updated", patch.title);
      }, "Visit saved.");
    },
  );
}
function questionForm(text = "") {
  form(
    "Keep a question for later",
    `<label>What would you like to ask?<textarea name="text" maxlength="2000" required>${esc(text)}</textarea></label>`,
    async (f) =>
      mutate((s) => {
        s.questions.unshift({ id: C.id(), text: f.get("text"), done: false });
        C.audit(s, "Question saved", f.get("text"));
      }, "Question saved."),
  );
}
function download(text, name, type = "text/plain") {
  const blob = text instanceof Blob ? text : new Blob([text], { type });
  const url = URL.createObjectURL(blob),
    a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}
function dataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(Error("Could not read this file."));
    reader.readAsDataURL(file);
  });
}
function calendar(title, date, time = "", description = "") {
  const clean = (s) =>
    s.replace(/\\/g, "\\\\").replace(/\r?\n/g, "\\n").replace(/[,;]/g, "\\$&");
  const start =
    date.replaceAll("-", "") + (time ? `T${time.replace(":", "")}00` : "");
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//CareInOne//Web//EN",
    "BEGIN:VEVENT",
    `UID:${C.id()}@careinone`,
    `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d+/, "")}`,
    `DTSTART${time ? "" : ";VALUE=DATE"}:${start}`,
    `SUMMARY:${clean(title)}`,
    `DESCRIPTION:${clean(description)}`,
    "END:VEVENT",
    "END:VCALENDAR",
  ];
  download(lines.join("\r\n"), "careinone-calendar.ics", "text/calendar");
}
async function api(path, method = "GET", body) {
  const response = await fetch(path, {
    method,
    headers: body
      ? { "Content-Type": "application/json", "X-CareInOne-Request": "1" }
      : {},
    body: body ? JSON.stringify(body) : undefined,
    credentials: "same-origin",
    cache: "no-store",
    signal: AbortSignal.timeout(190000),
  });
  let data;
  try {
    data = await response.json();
  } catch {
    throw Error("The web connection is unavailable. Local records are safe.");
  }
  if (!response.ok) throw Error(data.error || "Connection failed.");
  return data;
}
async function cloudConnection() {
  const meta = await api("/api/status");
  if (!meta.enabled) return { ...meta, authenticated: false };
  const session = await api("/api/session");
  if (!session.authenticated && meta.publicAccess) {
    await api("/api/connect", "POST", {});
    return { ...meta, authenticated: true };
  }
  return { ...meta, ...session };
}
async function cloudDialog() {
  const meta = await cloudConnection();
  if (!meta.enabled) {
    form(
      "Local care, ready when you are",
      `<p>AI analysis is currently unavailable. Capture, review, care records, visits, and backups still work locally.</p><p>Your records stay in this browser. You can continue reviewing them or save an encrypted backup, then try analysis again later.</p>`,
      async () => {},
      "Done",
    );
    return;
  }
  if (!meta.authenticated) {
    form(
      "Connect optional cloud analysis",
      `<p>Enter an access code issued by the CareInOne operator. This enables analysis, not cloud record storage. Never enter a model-provider API key.</p><label>Cloud access code<input name="code" type="password" autocomplete="off" required maxlength="200"></label>`,
      async (f) => {
        await api("/api/login", "POST", { code: f.get("code") });
        toast("Cloud connection enabled. Select a source to analyze.");
      },
      "Connect",
    );
    return;
  }
  cloud = await api("/api/config");
  form(
    "Your analysis connection",
    `${providerDisclosure(cloud)}<p>To analyze, open a saved source and choose Analyze with cloud. You'll confirm before any source text is sent. A daily allowance applies; local records and review remain available if it is used up.</p>`,
    async () => {},
    "Done",
  );
}
function providerDisclosure(config) {
  const names = {
    openai: "OpenAI",
    kimi: "Kimi",
    compatible: "Configured compatible provider",
    custom: "Configured provider",
    mock: "Synthetic test adapter",
  };
  return `<p><strong>Where this source text can go</strong></p>${Object.entries(
    config.providers,
  )
    .filter(([, p]) => p)
    .map(
      ([role, p]) =>
        `<div class="quote"><strong>${role === "primary" ? "Primary recipient" : "Fallback recipient if the primary fails"}: ${esc(names[p.adapter] || "Configured provider")}</strong><br>${esc(p.model)}<br><span class="meta">${esc(p.host)}</span></div>`,
    )
    .join(
      "",
    )}<p class="subtle">Source limit: ${Number(config.maxSourceCharacters).toLocaleString()} characters. The gateway does not store patient content. Provider and infrastructure retention depend on the operator's accounts and agreements.</p>`;
}
async function analyze(sourceId) {
  const session = await cloudConnection();
  if (!session.authenticated) {
    await cloudDialog();
    return;
  }
  const config = await api("/api/config"),
    src = state.sources.find((s) => s.id === sourceId);
  if (!src.text.trim())
    throw Error(
      "This original has no transcript text. Capture a typed transcript before cloud analysis.",
    );
  if (src.text.length > config.maxSourceCharacters)
    throw Error(
      "This source exceeds the gateway limit. Split its text into smaller sources.",
    );
  form(
    "Analyze this source?",
    `${providerDisclosure(config)}<p><strong>${esc(src.title)}</strong> · ${src.text.length.toLocaleString()} characters. Only this source text and its type/event date will be sent. The original attachment stays here.</p><label class="checkline"><input type="checkbox" name="consent" required><span>I allow this source text to be sent to the disclosed recipients for analysis.</span></label><p>Existing reviewed details remain unchanged. Pending proposals for this source will be replaced only after a valid response.</p>`,
    async (f) => {
      if (!f.get("consent")) throw Error("Consent is required.");
      const result = await api("/api/extract", "POST", {
        schemaVersion: "care-schema-1.0",
        providerConfigurationID: config.configurationID,
        consent: true,
        sourceKind: src.kind,
        text: src.text,
        eventDate: src.eventDate || null,
      });
      if (
        result.schemaVersion !== "care-schema-1.0" ||
        !Array.isArray(result.claims) ||
        result.claims.length > 200
      )
        throw Error("Unsupported analysis response.");
      const proposals = result.claims.map((c) => C.makeClaim(c, src));
      await mutate((s) => {
        s.claims = s.claims.filter(
          (c) => !(c.sourceId === sourceId && c.review === "pending"),
        );
        for (const c of proposals) {
          if (
            !s.claims.some(
              (old) =>
                old.sourceId === c.sourceId &&
                old.quote === c.quote &&
                old.kind === c.kind &&
                old.label === c.label &&
                old.value === c.value &&
                old.frequency === c.frequency &&
                old.action === c.action,
            )
          )
            s.claims.push(c);
        }
        C.audit(s, "Cloud proposals ready for review", src.title);
      }, "Analysis complete. Review every proposed detail.");
      location.hash = `review?source=${encodeURIComponent(sourceId)}`;
    },
    "Allow & analyze",
  );
}
const actions = {
  close: () => modal.close(),
  capture: captureForm,
  record: recordForm,
  "edit-claim": editClaim,
  start: async () => {
    await storage.save(state);
    ready = true;
    render();
  },
  demo: async () => {
    if (ready && state.sources.length)
      throw Error(
        "Clear or back up your workspace before loading the fictional example.",
      );
    const next = C.seedDemo();
    await storage.save(next);
    state = next;
    ready = true;
    location.hash = "today";
    render();
  },
  "clear-demo": () =>
    confirmAction(
      "Clear the fictional example?",
      "This removes the entire example workspace, including any edits you made to it.",
      async () => {
        await storage.clear(state._revision || 0);
        state = C.emptyState();
        ready = false;
        render();
      },
    ),
  accept: (id) =>
    mutate((s) => C.review(s, id, "accepted"), "Detail accepted as reviewed."),
  reject: (id) =>
    mutate((s) => C.review(s, id, "rejected"), "Detail rejected."),
  "delete-source": (id) => {
    const src = state.sources.find((x) => x.id === id),
      count = state.claims.filter((c) => c.sourceId === id).length;
    confirmAction(
      "Delete this original source?",
      `Remove “${src.title}”, its ${count} proposed details, original attachment, and linked follow-through entries? Export a backup first if needed.`,
      async () => {
        await mutate(
          (s) => C.deleteSource(s, id),
          "Source and linked details removed.",
        );
        location.hash = "sources";
      },
    );
  },
  attachment: (id) => {
    const a = state.sources.find((x) => x.id === id).attachment;
    const bytes = Uint8Array.from(atob(a.data.split(",")[1]), (c) =>
      c.charCodeAt(0),
    );
    download(new Blob([bytes], { type: a.type }), a.name);
  },
  "conflict-question": (key) => {
    const e = C.project(state).find((e) => e.key === key);
    questionForm(
      `My saved records differ about ${e.label}. Which details should I use, and should any prior report be marked historical?`,
    );
  },
  "add-task": () => editTask(),
  "edit-task": editTask,
  outreach: (taskId) => {
    const t = C.tasks(state).find((t) => t.id === taskId);
    form(
      "Make the next step a little easier",
      `<p>Use this draft as a starting point. Copy it to your usual clinic channel. Nothing is sent by this website.</p><label>Message / call script<textarea name="text" maxlength="10000">${esc(`Hello, I'm following up about ${t.title}. Could you confirm the current status and let me know the next step? Thank you.`)}</textarea></label><p>Save the draft or what happened after your call. Capture a clinical reply as a new source so it can be reviewed.</p>`,
      async (f) =>
        mutate((s) => {
          const existing = C.tasks(s).find((x) => x.id === taskId);
          C.updateTask(s, taskId, {
            outreach: [
              ...(existing.outreach || []),
              { text: f.get("text"), at: C.now() },
            ],
          });
        }, "Outreach note saved."),
      "Save outreach note",
    );
  },
  "task-calendar": (id) => {
    const t = C.tasks(state).find((t) => t.id === id);
    calendar(
      t.title,
      t.dueDate,
      "",
      "Personal check-back from CareInOne. Confirm any medical deadlines with your care team.",
    );
  },
  "add-visit": () => editVisit(),
  "edit-visit": editVisit,
  "delete-visit": (id) =>
    confirmAction(
      "Remove this visit?",
      "This removes its agenda and recap. Any recap already saved as a source remains in Sources.",
      async () =>
        mutate((s) => {
          const v = C.visits(s).find((v) => v.id === id);
          if (v.claimId) C.updateVisit(s, id, { hidden: true });
          else s.visits = s.visits.filter((v) => v.id !== id);
          C.audit(s, "Visit removed", v.title);
        }, "Visit removed."),
    ),
  "visit-calendar": (id) => {
    const v = C.visits(state).find((v) => v.id === id);
    calendar(v.title, v.date, v.time, v.agenda);
  },
  "recap-source": (id) => {
    const v = C.visits(state).find((v) => v.id === id);
    return mutate(
      (s) =>
        C.addSource(s, {
          title: `Visit recap · ${v.title}`,
          text: v.recap,
          eventDate: v.date,
          kind: "typed",
        }),
      "Recap saved for review.",
    );
  },
  "add-question": () => questionForm(),
  "toggle-question": (id) =>
    mutate((s) => {
      const q = s.questions.find((q) => q.id === id);
      q.done = !q.done;
      C.audit(s, q.done ? "Question discussed" : "Question reopened", q.text);
    }, "Question updated."),
  "delete-question": (id) =>
    mutate((s) => {
      s.questions = s.questions.filter((q) => q.id !== id);
    }, "Question removed."),
  profile: () =>
    form(
      "A little about you",
      `<label>Your preferred name (optional)<input name="name" value="${esc(state.profile.name)}" maxlength="100"></label><label>What matters most to you? (optional)<textarea name="priorities" maxlength="4000">${esc(state.profile.priorities)}</textarea></label>`,
      async (f) =>
        mutate((s) => {
          s.profile = Object.fromEntries(f);
          C.audit(s, "Profile updated", "Personal context");
        }, "Profile saved."),
    ),
  print: () => window.print(),
  "download-brief": () =>
    download(C.brief(state), `careinone-brief-${C.day()}.txt`),
  backup: () =>
    form(
      "Keep an encrypted copy",
      `<p>This downloads all web records and saved originals in an encrypted file. Keep both the file and passphrase safe.</p><label>Backup passphrase (12+ characters)<input name="password" type="password" minlength="12" required autocomplete="new-password"></label><label>Repeat passphrase<input name="repeat" type="password" minlength="12" required autocomplete="new-password"></label>`,
      async (f) => {
        if (f.get("password") !== f.get("repeat"))
          throw Error("The passphrases do not match.");
        download(
          await storage.encrypt(state, f.get("password")),
          `careinone-backup-${C.day()}.carebackup`,
          "application/json",
        );
        toast("Encrypted backup downloaded. Keep your passphrase safe.");
      },
      "Download backup",
    ),
  restore: () =>
    form(
      "Restore your encrypted backup",
      `<p>Restoring replaces all records in this browser workspace. Export a backup of the current workspace first if you want to keep it. Web backups are separate from native iOS backups.</p><label>Backup file<input name="file" type="file" accept=".carebackup,application/json" required></label><label>Backup passphrase<input name="password" type="password" required autocomplete="off"></label><label class="checkline"><input type="checkbox" name="replace" required><span>I understand this replaces the current workspace.</span></label>`,
      async (f) => {
        const file = f.get("file");
        if (file.size > 60000000)
          throw Error("This backup exceeds the 60 MB web limit.");
        const restored = await storage.decrypt(
          await file.text(),
          f.get("password"),
        );
        await storage.save(restored, state._revision || 0);
        state = restored;
        ready = true;
        render();
        toast("Encrypted backup restored.");
      },
      "Decrypt & replace workspace",
    ),
  clear: () =>
    confirmAction(
      "Clear all records from this browser?",
      "This removes the profile, sources and originals, reviews, tasks, visits, questions, and activity. Export a backup first if you need to keep them.",
      async () => {
        await storage.clear(state._revision || 0);
        state = C.emptyState();
        ready = false;
        render();
        toast("Workspace cleared from this browser.");
      },
    ),
  persist: async () => {
    const granted = await navigator.storage?.persist?.();
    toast(
      granted
        ? "Persistent storage is enabled. Keep regular backups too."
        : "This browser did not grant persistent storage. Use encrypted backups regularly.",
    );
  },
  cloud: cloudDialog,
  analyze,
  disconnect: async () => {
    await api("/api/logout", "POST", {});
    cloud = null;
    toast("Cloud access disconnected. Local records are unchanged.");
  },
};
document.addEventListener("click", async (e) => {
  if (e.target.closest(".skip")) {
    e.preventDefault();
    $("#main")?.focus();
    return;
  }
  const b = e.target.closest("[data-action]");
  if (!b) return;
  const action = actions[b.dataset.action];
  if (!action) return;
  try {
    await action(b.dataset.id);
  } catch (err) {
    toast(
      err.message || "Something went wrong. Your saved records are unchanged.",
    );
  }
});
window.addEventListener("hashchange", () => {
  render();
  window.scrollTo(0, 0);
});
// Avoid overwriting a newer workspace from another tab without a reload.
storage.subscribe(async () => {
  if (modal.open) {
    toast(
      "Records changed in another tab. Close this dialog and reload before editing.",
    );
    return;
  }
  try {
    const updated = await storage.load();
    if (updated) {
      state = C.validateState(updated);
      ready = true;
    } else {
      state = C.emptyState();
      ready = false;
    }
    render();
  } catch (e) {
    toast(e.message);
  }
});
document.addEventListener("visibilitychange", async () => {
  if (document.visibilityState === "visible" && !modal.open && !busy) {
    try {
      const loaded = await storage.load();
      if (loaded) {
        state = C.validateState(loaded);
        ready = true;
      } else {
        state = C.emptyState();
        ready = false;
      }
      render();
    } catch (e) {
      toast(e.message);
    }
  }
});
let initialSaved;
try {
  initialSaved = await storage.load();
  if (initialSaved) {
    state = C.validateState(initialSaved);
    ready = true;
  }
  render();
} catch (e) {
  state = C.emptyState();
  state._revision = storage.revision(initialSaved);
  $("#app").innerHTML =
    `<main class="onboard"><h1>Your workspace could not be opened.</h1><p>${esc(e.message)}</p><p>Try your usual browser profile with storage enabled. Existing saved data has not been erased. If you have a valid encrypted backup, you can choose to replace this workspace.</p>${button("Restore a backup", "restore", "", "primary")}</main>`;
}
