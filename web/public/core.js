// Browser-specific care engine. Evidence is immutable; review is explicit.
export const VERSION = "careinone-web-1";
export const kinds = {
  medication: "Medication",
  condition: "Condition",
  allergy: "Allergy",
  labTest: "Test",
  resultType: "Result",
  referral: "Referral",
  appointment: "Appointment",
  procedure: "Procedure",
  provider: "Care team",
  instruction: "Instruction",
  followUp: "Follow-up",
  administrativeTask: "Task",
  other: "Note",
};
export const id = () => crypto.randomUUID();
export const now = () => new Date().toISOString();
export const day = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
export function emptyState() {
  return {
    version: VERSION,
    profile: { name: "", priorities: "" },
    sources: [],
    claims: [],
    tasks: [],
    visits: [],
    questions: [],
    history: [],
    demo: false,
  };
}
export function validDate(s) {
  return (
    typeof s === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(s) &&
    !Number.isNaN(Date.parse(s)) &&
    new Date(s).toISOString().slice(0, 10) === s
  );
}
export function extract(text, eventDate = "") {
  return text
    .split(/\r?\n/)
    .filter((s) => s.trim())
    .flatMap((line) =>
      Array.from({ length: Math.ceil(line.length / 5500) }, (_, i) =>
        line.slice(i * 5500, (i + 1) * 5500),
      ),
    )
    .slice(0, 200)
    .map((quote) => {
      const l = quote.toLowerCase();
      let kind = "other",
        action = "mentioned",
        label = quote.slice(0, 100),
        value = "",
        numericValue = null,
        unit = "";
      const dose = quote.match(
        /\b([a-z][a-z-]{2,}(?:\s+(?:succinate|tartrate|hydrochloride))?)\s+(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml)\b/i,
      );
      if (
        dose &&
        !["take", "dose", "increase", "decrease", "given"].includes(
          dose[1].toLowerCase(),
        )
      ) {
        kind = "medication";
        label = dose[1];
        value = `${dose[2]} ${dose[3]}`;
        action = /\b(stop|discontinue)\b/.test(l)
          ? "stopped"
          : /\b(start|begin)\b/.test(l)
            ? "started"
            : /\b(increase|decrease|change)\b/.test(l)
              ? "changed"
              : "taking";
      } else {
        const prefix = quote
          .trim()
          .match(
            /^(allerg(?:y|ies)|condition|provider|procedure|task|instruction|result):\s*(.+)/i,
          );
        if (prefix) {
          kind = {
            allergy: "allergy",
            allergies: "allergy",
            condition: "condition",
            provider: "provider",
            procedure: "procedure",
            task: "administrativeTask",
            instruction: "instruction",
            result: "resultType",
          }[prefix[1].toLowerCase()];
          label = prefix[2].slice(0, 200);
          if (kind === "administrativeTask") action = "requested";
        } else if (/\b(referral|referred)\b/.test(l)) {
          kind = "referral";
          action = "requested";
        } else if (/follow[ -]up|return in/.test(l)) {
          kind = "followUp";
          action = "requested";
        } else if (/appointment|scheduled visit/.test(l)) {
          kind = "appointment";
          action = "scheduled";
        } else if (
          /\b(blood test|lab test|mri|ct scan|echocardiogram|cbc|a1c)\b/.test(l)
        ) {
          kind = "labTest";
          label = quote.match(
            /\b(blood test|lab test|mri|ct scan|echocardiogram|cbc|a1c)\b/i,
          )[0];
          action = /\b(ordered|requested|obtain)\b/.test(l)
            ? "ordered"
            : /\b(completed|performed)\b/.test(l)
              ? "completed"
              : "mentioned";
        }
      }
      if (kind === "resultType") {
        const result = label.match(
          /^(.+?)\s*(?:[:=]\s*|\s+)([-+]?\d+(?:\.\d+)?)\s*(\S[^\n]{0,39})?$/,
        );
        if (result) {
          label = result[1].trim();
          numericValue = Number(result[2]);
          unit = result[3]?.trim() || "";
          value = `${numericValue} ${unit}`.trim();
        }
      }
      if (
        [
          "referral",
          "followUp",
          "appointment",
          "labTest",
          "procedure",
          "administrativeTask",
        ].includes(kind)
      ) {
        if (/\b(cancelled|canceled|cancel)\b/.test(l)) action = "dismissed";
        else if (/\b(completed|performed|finished)\b/.test(l))
          action = "completed";
      }
      const family = /\b(mother|father|sister|brother|family history)\b/.test(
          l,
        ),
        other = /\b(my wife|my husband|my child|my partner)\b/.test(l),
        conditional = /\b(consider|if|might|possibly|could|may need)\b/.test(l),
        negated = /\b(no|not|denies|without|never)\b/.test(l);
      const date = quote.match(/\b\d{4}-\d{2}-\d{2}\b/)?.[0];
      return {
        kind,
        action,
        label,
        quote,
        value,
        numericValue,
        unit,
        eventDate,
        subject: family ? "family" : other ? "other" : "patient",
        conditional,
        negated,
        certainty: /\b(previously|historical|used to)\b/.test(l)
          ? "historical"
          : conditional
            ? "conditional"
            : /\b(unsure|not sure|uncertain)\b/.test(l)
              ? "uncertain"
              : "reported",
        frequency:
          [
            "twice daily",
            "once daily",
            "three times daily",
            "daily",
            "weekly",
            "as needed",
          ].find((x) => l.includes(x)) || "",
        dueDate: validDate(date) ? date : "",
        duePrecision: validDate(date) ? "exact" : "unknown",
        extraction: "local-conservative-web-1",
      };
    });
}
export function audit(s, action, label) {
  s.history.unshift({ id: id(), at: now(), action, label });
  s.history = s.history.slice(0, 1000);
}
export function addSource(
  s,
  {
    title,
    text,
    kind = "typed",
    eventDate = "",
    attachment = null,
    pages = [],
  },
  proposals = null,
) {
  if (
    typeof text !== "string" ||
    (!text.trim() && !attachment) ||
    text.length > 200000
  )
    throw Error("Enter source text, up to 200,000 characters.");
  if (eventDate && !validDate(eventDate))
    throw Error("Choose a valid event date.");
  const normalized = text.trim();
  if (
    normalized &&
    s.sources.some(
      (x) =>
        x.text === normalized && x.eventDate === eventDate && x.kind === kind,
    )
  )
    throw Error("This exact source is already saved.");
  const source = {
    id: id(),
    title: (title || "Personal update").trim().slice(0, 200),
    text: normalized,
    kind,
    eventDate,
    capturedAt: now(),
    attachment,
    pages,
  };
  const candidates =
    proposals ??
    (pages.length
      ? pages
          .flatMap((p) =>
            extract(p.text.trim(), eventDate).map((c) => ({
              ...c,
              page: p.number,
            })),
          )
          .slice(0, 200)
      : extract(source.text, eventDate));
  const claims = candidates.map((raw) => makeClaim(raw, source));
  s.sources.unshift(source);
  s.claims.push(...claims);
  audit(s, "Source captured", source.title);
  return source;
}
const certainties = [
  "unknown",
  "notProvided",
  "reported",
  "documented",
  "uncertain",
  "conditional",
  "disputed",
  "historical",
  "superseded",
  "completedByUserReport",
];
const subjects = ["patient", "family", "other", "unknown"];
const actions =
  "mentioned taking started stopped changed ordered requested scheduled completed resultAvailable followUpKnown referralPlaced appointmentScheduled visitCompleted planned prepNeeded inProgress dismissed".split(
    " ",
  );
export function makeClaim(raw, source) {
  if (
    !raw ||
    !Object.hasOwn(kinds, raw.kind) ||
    typeof raw.label !== "string" ||
    !raw.label.trim() ||
    raw.label.length > 200 ||
    typeof raw.quote !== "string" ||
    !raw.quote.trim() ||
    raw.quote.length > 6000 ||
    !source.text.includes(raw.quote)
  )
    throw Error(
      "Analysis returned an unsupported proposal or a quote absent from the source.",
    );
  for (const k of [
    "value",
    "frequency",
    "route",
    "form",
    "unit",
    "certainty",
    "subject",
    "action",
    "duePrecision",
    "clarification",
  ])
    if (raw[k] != null && typeof raw[k] !== "string")
      throw Error("Analysis returned invalid proposal fields.");
  for (const [k, limit] of [
    ["value", 4000],
    ["frequency", 200],
    ["route", 200],
    ["form", 200],
    ["unit", 80],
    ["clarification", 500],
  ])
    if (raw[k] != null && raw[k].length > limit)
      throw Error("Oversized proposal field.");
  for (const [field, allowed] of [
    ["certainty", certainties],
    ["subject", subjects],
    ["action", actions],
    ["duePrecision", ["unknown", "exact", "approximate"]],
  ])
    if (raw[field] != null && !allowed.includes(raw[field]))
      throw Error("Invalid proposal attribution or status.");
  for (const k of ["conditional", "negated"])
    if (raw[k] != null && typeof raw[k] !== "boolean")
      throw Error("Invalid proposal flags.");
  if (
    raw.numericValue != null &&
    (typeof raw.numericValue !== "number" || !Number.isFinite(raw.numericValue))
  )
    throw Error("Invalid numeric value.");
  for (const k of ["eventDate", "effectiveDate", "dueDate"])
    if (raw[k] && !validDate(raw[k].slice(0, 10)))
      throw Error("Analysis returned an invalid date.");
  if (
    raw.page != null &&
    (!Number.isInteger(raw.page) || raw.page < 1 || raw.page > 200)
  )
    throw Error("Invalid page reference.");
  const page =
    raw.page != null &&
    source.pages?.some(
      (p) => p.number === raw.page && p.text.includes(raw.quote),
    )
      ? raw.page
      : null;
  return {
    id: id(),
    sourceId: source.id,
    page,
    numericValue: raw.numericValue ?? null,
    unit: raw.unit || "",
    kind: raw.kind,
    label: raw.label,
    quote: raw.quote,
    action: raw.action || "mentioned",
    value:
      raw.value ||
      (raw.numericValue != null
        ? `${raw.numericValue} ${raw.unit || ""}`.trim()
        : ""),
    frequency: raw.frequency || "",
    route: raw.route || "",
    form: raw.form || "",
    eventDate: raw.eventDate?.slice(0, 10) || source.eventDate || "",
    dueDate: raw.dueDate?.slice(0, 10) || "",
    duePrecision: raw.duePrecision || "unknown",
    certainty: raw.certainty || "uncertain",
    subject: raw.subject || "unknown",
    conditional: raw.conditional === true,
    negated: raw.negated === true,
    clarification: raw.clarification || "",
    extraction: raw.extraction || "cloud-proposal",
    review: "pending",
    reviewedAt: null,
  };
}
export function review(s, claimId, status, edits = {}) {
  const c = s.claims.find((x) => x.id === claimId);
  if (!c || !["accepted", "rejected", "pending"].includes(status))
    throw Error("Invalid review.");
  const source = s.sources.find((x) => x.id === c.sourceId);
  if (!source) throw Error("Supporting source is missing.");
  const allowed = [
    "label",
    "kind",
    "value",
    "frequency",
    "certainty",
    "subject",
    "action",
    "dueDate",
    "duePrecision",
  ];
  const candidate = {
    ...c,
    ...Object.fromEntries(
      Object.entries(edits).filter(([k]) => allowed.includes(k)),
    ),
  };
  if (
    !Object.hasOwn(kinds, candidate.kind) ||
    typeof candidate.label !== "string" ||
    !candidate.label.trim() ||
    candidate.label.length > 200 ||
    (candidate.dueDate && !validDate(candidate.dueDate))
  )
    throw Error("Check the label, category, and date.");
  if (candidate.value !== c.value) {
    const m =
      candidate.kind === "resultType"
        ? candidate.value.match(/^([-+]?\d+(?:\.\d+)?)\s*(.*?)$/)
        : null;
    candidate.numericValue = m ? Number(m[1]) : null;
    candidate.unit = m ? m[2] : "";
  }
  makeClaim(candidate, source);
  Object.assign(c, candidate, { review: status, reviewedAt: now() });
  audit(s, `Proposal ${status}`, c.label);
}
export function eligible(c) {
  return (
    c.review === "accepted" &&
    c.subject === "patient" &&
    !c.conditional &&
    !c.negated &&
    ![
      "historical",
      "uncertain",
      "disputed",
      "superseded",
      "unknown",
      "notProvided",
    ].includes(c.certainty)
  );
}
const key = (c) =>
  `${c.kind}:${c.label.trim().toLowerCase().replace(/\s+/g, " ")}`;
export function project(s) {
  const groups = new Map();
  for (const c of s.claims.filter(eligible)) {
    const k = key(c);
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(c);
  }
  return [...groups.values()].map((claims) => {
    const payload = (c) =>
      JSON.stringify([c.action, c.value, c.frequency, c.route, c.form]);
    const conflict =
      claims[0].kind === "resultType"
        ? claims.some((c) =>
            claims.some(
              (other) =>
                c.eventDate === other.eventDate &&
                payload(c) !== payload(other),
            ),
          )
        : new Set(claims.map(payload)).size > 1;
    return {
      key: key(claims[0]),
      label: claims[0].label,
      kind: claims[0].kind,
      claims,
      conflict,
      status: conflict
        ? "Needs clarification"
        : claims[0].kind === "resultType"
          ? "Reported observations"
          : claims[0].action === "stopped"
            ? "Reported stopped"
            : "Reviewed",
    };
  });
}
export function tasks(s) {
  const list = s.tasks.map((t) =>
    t.claimId && !s.claims.some((c) => c.id === t.claimId && eligible(c))
      ? { ...t, status: "paused", paused: true }
      : t,
  );
  for (const c of s.claims.filter(eligible)) {
    if (
      [
        "referral",
        "followUp",
        "administrativeTask",
        "labTest",
        "procedure",
      ].includes(c.kind) &&
      [
        "requested",
        "ordered",
        "scheduled",
        "planned",
        "referralPlaced",
        "prepNeeded",
      ].includes(c.action)
    ) {
      const saved = s.tasks.find((t) => t.claimId === c.id);
      if (!saved)
        list.push({
          id: `claim:${c.id}`,
          claimId: c.id,
          title: c.label,
          dueDate: c.dueDate,
          duePrecision: c.duePrecision,
          status: "open",
          notes: "",
          outreach: [],
        });
    }
  }
  return list;
}
export function updateTask(s, taskId, patch) {
  let t = s.tasks.find((x) => x.id === taskId);
  if (!t) {
    const generated = tasks(s).find((x) => x.id === taskId);
    if (!generated) throw Error("Task no longer exists.");
    t = { ...generated };
    s.tasks.push(t);
  }
  Object.assign(t, patch);
  audit(s, "Follow-through updated", t.title);
}
export function visits(s) {
  const list = s.visits.map((v) =>
    v.claimId && !s.claims.some((c) => c.id === v.claimId && eligible(c))
      ? { ...v, status: "paused", paused: true }
      : v,
  );
  for (const c of s.claims.filter(eligible)) {
    if (
      c.kind !== "appointment" ||
      ![
        "scheduled",
        "appointmentScheduled",
        "planned",
        "completed",
        "visitCompleted",
      ].includes(c.action) ||
      list.some((v) => v.claimId === c.id)
    )
      continue;
    list.push({
      id: `claim:${c.id}`,
      claimId: c.id,
      title: c.label,
      date: c.dueDate || "",
      time: "",
      provider: "",
      agenda: "",
      recap: "",
      status: ["completed", "visitCompleted"].includes(c.action)
        ? "completed"
        : "planned",
    });
  }
  return list.filter((v) => !v.hidden);
}
export function updateVisit(s, visitId, patch) {
  let v = s.visits.find((v) => v.id === visitId);
  if (!v) {
    const generated = visits(s).find((v) => v.id === visitId);
    if (!generated) throw Error("Visit no longer exists.");
    v = { ...generated };
    s.visits.push(v);
  }
  Object.assign(v, patch);
  audit(s, "Visit updated", v.title);
}
export function deleteSource(s, sourceId) {
  const source = s.sources.find((x) => x.id === sourceId);
  if (!source) return;
  const ids = new Set(
    s.claims.filter((c) => c.sourceId === sourceId).map((c) => c.id),
  );
  s.sources = s.sources.filter((x) => x.id !== sourceId);
  s.claims = s.claims.filter((c) => c.sourceId !== sourceId);
  s.tasks = s.tasks.filter((t) => !ids.has(t.claimId));
  s.visits = s.visits.filter((v) => !ids.has(v.claimId));
  audit(s, "Source and linked proposals removed", source.title);
}
export function brief(s) {
  const lines = [
    "CAREINONE · PERSONAL CARE BRIEF",
    s.profile.name || "Name not provided",
    `Prepared ${new Date().toLocaleString()}`,
    "Patient-organized information. Confirm clinical decisions with the care team.",
  ];
  if (s.profile.priorities) lines.push("\nMY PRIORITIES", s.profile.priorities);
  for (const e of project(s)) {
    lines.push(`\n${kinds[e.kind]} · ${e.label} · ${e.status}`);
    for (const c of e.claims) {
      const src = s.sources.find((x) => x.id === c.sourceId);
      lines.push(
        `  ${[c.value, c.frequency, c.action].filter(Boolean).join(" · ")}`,
        `  “${c.quote}”`,
        `  Source: ${src.title}${c.page ? `; page ${c.page}` : ""}; event: ${src.eventDate || "unknown"}; captured: ${src.capturedAt.slice(0, 10)}`,
      );
    }
  }
  lines.push("\nOPEN FOLLOW-THROUGH");
  tasks(s)
    .filter((t) => t.status === "open")
    .forEach((t) =>
      lines.push(
        `• ${t.title}${t.dueDate ? ` — ${t.duePrecision === "exact" ? "" : t.duePrecision === "approximate" ? "approximately " : "precision unknown: "}${t.dueDate}` : " — date not provided"}`,
      ),
    );
  lines.push("\nQUESTIONS");
  s.questions.filter((q) => !q.done).forEach((q) => lines.push(`• ${q.text}`));
  lines.push(
    "\nReviewed statements with historical, uncertain, conditional, negative or non-patient attribution are excluded from this current-care brief. Originals remain in Sources.",
  );
  return lines.join("\n");
}
export function validateState(s) {
  if (
    !s ||
    s.version !== VERSION ||
    !s.profile ||
    typeof s.profile.name !== "string" ||
    typeof s.profile.priorities !== "string"
  )
    throw Error("Unsupported backup format.");
  for (const k of [
    "sources",
    "claims",
    "tasks",
    "visits",
    "questions",
    "history",
  ])
    if (!Array.isArray(s[k]) || s[k].length > 10000)
      throw Error("Invalid backup records.");
  const ids = new Set();
  for (const src of s.sources) {
    if (
      typeof src.id !== "string" ||
      ids.has(src.id) ||
      typeof src.text !== "string" ||
      src.text.length > 200000 ||
      typeof src.title !== "string" ||
      typeof src.capturedAt !== "string" ||
      (src.eventDate && !validDate(src.eventDate))
    )
      throw Error("Invalid source in backup.");
    ids.add(src.id);
    if (
      src.attachment &&
      (typeof src.attachment.data !== "string" ||
        !/^data:(application\/(pdf|json)|image\/(png|jpeg|webp)|audio\/(webm|ogg|mp4|mpeg|wav)(;codecs=[a-z0-9.,_-]+)?);base64,[A-Za-z0-9+/=]*$/.test(
          src.attachment.data,
        ))
    )
      throw Error("Unsupported attachment in backup.");
  }
  const claimIds = new Set();
  for (const c of s.claims) {
    const src = s.sources.find((x) => x.id === c.sourceId);
    if (
      !src ||
      typeof c.id !== "string" ||
      claimIds.has(c.id) ||
      !["pending", "accepted", "rejected"].includes(c.review)
    )
      throw Error("Invalid claim in backup.");
    makeClaim(c, src);
    claimIds.add(c.id);
  }
  for (const t of s.tasks)
    if (
      typeof t.id !== "string" ||
      typeof t.title !== "string" ||
      !["open", "completed", "dismissed"].includes(t.status) ||
      !Array.isArray(t.outreach) ||
      t.outreach.some(
        (o) => !o || typeof o.text !== "string" || typeof o.at !== "string",
      ) ||
      typeof t.notes !== "string" ||
      (t.claimId && !claimIds.has(t.claimId)) ||
      (t.dueDate && !validDate(t.dueDate))
    )
      throw Error("Invalid task in backup.");
  for (const v of s.visits)
    if (
      typeof v.id !== "string" ||
      typeof v.title !== "string" ||
      typeof v.date !== "string" ||
      (v.date && !validDate(v.date)) ||
      typeof v.agenda !== "string" ||
      typeof v.recap !== "string" ||
      typeof v.provider !== "string" ||
      typeof v.time !== "string" ||
      !["planned", "completed", "dismissed"].includes(v.status) ||
      (v.claimId && !claimIds.has(v.claimId))
    )
      throw Error("Invalid visit in backup.");
  for (const q of s.questions)
    if (
      typeof q.id !== "string" ||
      typeof q.text !== "string" ||
      typeof q.done !== "boolean"
    )
      throw Error("Invalid question in backup.");
  for (const h of s.history)
    if (
      typeof h.action !== "string" ||
      typeof h.label !== "string" ||
      typeof h.at !== "string"
    )
      throw Error("Invalid history in backup.");
  return s;
}
export function seedDemo() {
  const s = emptyState();
  s.demo = true;
  s.profile.name = "Alex Morgan";
  s.profile.priorities =
    "Understand my next steps and bring a clear medication list.";
  addSource(s, {
    title: "Example · Primary care visit",
    text: "Condition: high blood pressure\nLisinopril 10 mg once daily\nAllergy: penicillin\nReferral to cardiology requested\nTask: request the visit summary",
    eventDate: day(),
  });
  s.claims.forEach((c) => review(s, c.id, "accepted"));
  addSource(s, {
    title: "Example · Discharge note",
    text: "Lisinopril 20 mg once daily",
    eventDate: day(),
  });
  s.claims
    .filter((c) => c.review === "pending")
    .forEach((c) => review(s, c.id, "accepted"));
  addSource(s, {
    title: "Example · A quick update",
    text: "I would like to ask about my referral.\nFollow-up appointment requested",
  });
  const d = new Date();
  d.setDate(d.getDate() + 7);
  s.visits.push({
    id: id(),
    title: "Primary care check-in",
    date: d.toLocaleDateString("en-CA"),
    time: "10:00",
    provider: "Dr. Rivera · Example clinic",
    agenda: "Review medication differences\nCheck the referral status",
    recap: "",
    status: "planned",
  });
  s.questions.push({
    id: id(),
    text: "Which medication dose should my records show?",
    done: false,
  });
  return s;
}
