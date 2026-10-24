import test from "node:test";
import assert from "node:assert/strict";
import * as C from "../public/core.js";
import { trends, ask, evidenceMap } from "../public/insights.js";
function measured(s, text, date) {
  C.addSource(s, { text, eventDate: date });
  C.review(s, s.claims.at(-1).id, "accepted");
}
test("numeric results preserve units and dates; distinct units never share a series", () => {
  const s = C.emptyState();
  measured(s, "Result: Glucose = 95 mg/dL", "2026-10-01");
  measured(s, "Result: Glucose = 100 mg/dL", "2026-10-15");
  measured(s, "Result: Glucose = 5.5 mmol/L", "2026-10-16");
  const groups = trends(s);
  assert.equal(groups.length, 2);
  assert.equal(groups[0].points.length, 2);
  assert.equal(groups[0].points[0].value, 95);
  assert.equal(groups[1].unit, "mmol/L");
  assert.equal(
    C.project(s).some((e) => e.conflict),
    false,
  );
});
test("unknown dates and missing numbers are never replaced with zero", () => {
  const s = C.emptyState();
  measured(s, "Result: Glucose = 95 mg/dL", "");
  measured(s, "Result: Glucose not provided", "");
  const groups = trends(s);
  assert.equal(groups.length, 1);
  assert.equal(groups[0].points[0].date, "");
  assert.equal(groups[0].points[0].value, 95);
});
test("editing a reported numeric value cannot leave the old value on the chart", () => {
  const s = C.emptyState();
  measured(s, "Result: Glucose = 95 mg/dL", "2026-10-01");
  C.review(s, s.claims[0].id, "accepted", { value: "100 mg/dL" });
  assert.equal(trends(s)[0].points[0].value, 100);
  C.review(s, s.claims[0].id, "accepted", { value: "unknown" });
  assert.equal(trends(s).length, 0);
});
test("Ask returns original matching claims and no invented answer when records are absent", () => {
  const s = C.seedDemo();
  const found = ask(s, "What do my notes say about lisinopril?");
  assert.equal(found.length, 2);
  assert.ok(
    found.every((c) =>
      s.sources.find((src) => src.id === c.sourceId).text.includes(c.quote),
    ),
  );
  assert.deepEqual(ask(s, "unrecorded thyroid measurement"), []);
});
test("evidence map loses deleted source and dependent statements", () => {
  const s = C.seedDemo();
  const target = s.sources[0].id;
  C.deleteSource(s, target);
  assert.ok(!evidenceMap(s).some((row) => row.source.id === target));
});
