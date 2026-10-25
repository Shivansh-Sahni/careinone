// Deterministic, evidence-linked browser insights. No diagnosis or generated answers.
import { eligible } from "./core.js";
export function trends(state) {
  const groups = new Map();
  for (const claim of state.claims.filter(eligible)) {
    if (
      claim.kind !== "resultType" ||
      typeof claim.numericValue !== "number" ||
      !Number.isFinite(claim.numericValue)
    )
      continue;
    const key = JSON.stringify([
      claim.label.trim().toLowerCase(),
      claim.unit || "",
    ]);
    if (!groups.has(key))
      groups.set(key, {
        label: claim.label,
        unit: claim.unit || "",
        points: [],
      });
    groups
      .get(key)
      .points.push({
        value: claim.numericValue,
        date: claim.eventDate || "",
        claimId: claim.id,
        sourceId: claim.sourceId,
        quote: claim.quote,
      });
  }
  return [...groups.values()].map((g) => ({
    ...g,
    points: g.points.sort((a, b) =>
      (a.date || "9999").localeCompare(b.date || "9999"),
    ),
  }));
}
const tokens = (text) =>
  new Set(text.toLowerCase().match(/[a-z0-9]{3,}/g) || []);
const stop = new Set(
  "the and for from with what when where which about have does this that are how was were can my".split(
    " ",
  ),
);
export function ask(state, question) {
  const terms = [...tokens(question)].filter((t) => !stop.has(t));
  if (!terms.length) return [];
  return state.claims
    .map((c) => {
      const hay = tokens(`${c.label} ${c.value} ${c.quote}`);
      return { claim: c, score: terms.filter((t) => hay.has(t)).length };
    })
    .filter((x) => x.score > 0)
    .sort(
      (a, b) =>
        b.score - a.score || a.claim.sourceId.localeCompare(b.claim.sourceId),
    )
    .slice(0, 12)
    .map((x) => x.claim);
}
export function evidenceMap(state) {
  return state.sources.map((source) => ({
    source,
    claims: state.claims.filter((c) => c.sourceId === source.id),
  }));
}
