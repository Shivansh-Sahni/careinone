import test from "node:test";
import assert from "node:assert/strict";
import * as C from "../public/core.js";
import { encrypt, decrypt } from "../public/storage.js";
const source = (s, text, title = "Test source") =>
  C.addSource(s, { title, text });
test("capture preserves exact evidence and requires review before care projection", () => {
  const s = C.emptyState();
  const src = source(s, "Lisinopril 10 mg once daily");
  assert.equal(src.text, "Lisinopril 10 mg once daily");
  assert.equal(C.project(s).length, 0);
  C.review(s, s.claims[0].id, "accepted");
  assert.equal(C.project(s)[0].claims[0].quote, src.text);
});
test("different accepted doses preserve both sources without selecting a winner", () => {
  const s = C.emptyState();
  source(s, "Lisinopril 10 mg once daily");
  source(s, "Lisinopril 20 mg once daily");
  s.claims.forEach((c) => C.review(s, c.id, "accepted"));
  const p = C.project(s);
  assert.equal(p.length, 1);
  assert.equal(p[0].conflict, true);
  assert.equal(p[0].claims.length, 2);
  assert.match(C.brief(s), /Needs clarification/);
});
test("acceptance never promotes family, negated, historical, conditional or uncertain statements", () => {
  for (const text of [
    "My mother takes Lisinopril 10 mg daily",
    "No Lisinopril 10 mg daily",
    "Previously Lisinopril 10 mg daily",
    "Consider Lisinopril 10 mg daily if needed",
    "Unsure about Lisinopril 10 mg daily",
  ]) {
    const s = C.emptyState();
    source(s, text);
    C.review(s, s.claims[0].id, "accepted");
    assert.equal(C.project(s).length, 0, text);
    assert.equal(s.claims.length, 1);
  }
});
test("reject, reopen, and correction update projection while preserving quote", () => {
  const s = C.emptyState();
  source(s, "Lisinopril 10 mg daily");
  const id = s.claims[0].id;
  C.review(s, id, "accepted", { value: "20 mg" });
  assert.equal(C.project(s)[0].claims[0].value, "20 mg");
  assert.equal(s.claims[0].quote, "Lisinopril 10 mg daily");
  C.review(s, id, "rejected");
  assert.equal(C.project(s).length, 0);
  C.review(s, id, "pending");
  assert.equal(s.claims[0].review, "pending");
});
test("duplicate capture is rejected without adding a second source", () => {
  const s = C.emptyState();
  source(s, "Test");
  assert.throws(() => source(s, "Test"), /already saved/);
  assert.equal(s.sources.length, 1);
});
test("forged cloud quotation is rejected atomically before source insertion", () => {
  const s = C.emptyState();
  assert.throws(
    () =>
      C.addSource(s, { text: "Original" }, [
        { kind: "medication", label: "Drug", quote: "Fabricated" },
      ]),
    /absent/,
  );
  assert.equal(s.sources.length, 0);
});
test("deleting supporting source removes its claims and generated task state", () => {
  const s = C.emptyState();
  const src = source(s, "Referral to cardiology requested");
  C.review(s, s.claims[0].id, "accepted");
  const t = C.tasks(s)[0];
  C.updateTask(s, t.id, { status: "completed" });
  assert.equal(C.tasks(s)[0].status, "completed");
  C.deleteSource(s, src.id);
  assert.equal(C.tasks(s).length, 0);
  assert.equal(C.project(s).length, 0);
  assert.equal(s.claims.length, 0);
  assert.match(s.history[0].action, /removed/);
});
test("task completion does not imply source evidence changed", () => {
  const s = C.emptyState();
  source(s, "CBC ordered");
  C.review(s, s.claims[0].id, "accepted");
  C.updateTask(s, C.tasks(s)[0].id, { status: "completed" });
  assert.equal(s.claims[0].action, "ordered");
  assert.equal(C.tasks(s).length, 1);
});
test("no date is invented from capture date or unanchored relative text", () => {
  const s = C.emptyState();
  source(s, "Follow up in 2 weeks");
  assert.equal(s.sources[0].eventDate, "");
  assert.equal(s.claims[0].dueDate, "");
  assert.equal(s.claims[0].duePrecision, "unknown");
});
test("date parser rejects rolled dates and date edits must be valid", () => {
  assert.equal(C.validDate("2026-02-30"), false);
  assert.equal(C.validDate("2024-02-29"), true);
  const s = C.emptyState();
  source(s, "CBC ordered");
  assert.throws(() =>
    C.review(s, s.claims[0].id, "accepted", { dueDate: "2026-02-30" }),
  );
});
test("backup validates evidence references, duplicate IDs and quote provenance", () => {
  const s = C.seedDemo();
  assert.equal(C.validateState(s), s);
  const bad = structuredClone(s);
  bad.claims[0].quote = "invented";
  assert.throws(() => C.validateState(bad));
  const duplicate = structuredClone(s);
  duplicate.sources.push(duplicate.sources[0]);
  assert.throws(() => C.validateState(duplicate));
});
test("backup encryption round trip preserves all records and rejects wrong password/tampering", async () => {
  const s = C.seedDemo(),
    encrypted = await encrypt(s, "a test passphrase 123");
  assert.ok(!encrypted.includes("Lisinopril"));
  assert.deepEqual(await decrypt(encrypted, "a test passphrase 123"), s);
  await assert.rejects(() => decrypt(encrypted, "incorrect passphrase"));
  const box = JSON.parse(encrypted);
  box.data = (box.data[0] === "a" ? "b" : "a") + box.data.slice(1);
  await assert.rejects(() =>
    decrypt(JSON.stringify(box), "a test passphrase 123"),
  );
});
test("short backup password is rejected", async () =>
  await assert.rejects(() => encrypt(C.emptyState(), "short"), /12/));
test("synthetic demonstration is explicitly labeled and includes real source conflicts", () => {
  const s = C.seedDemo();
  assert.equal(s.demo, true);
  assert.ok(C.project(s).some((e) => e.conflict));
  assert.ok(s.claims.some((c) => c.review === "pending"));
  assert.equal(s.visits.length, 1);
  assert.ok(C.tasks(s).length > 0);
});
test("identical observations on different event dates are separate source evidence", () => {
  const s = C.emptyState();
  C.addSource(s, {
    text: "Result: Glucose = 95 mg/dL",
    eventDate: "2026-10-01",
  });
  C.addSource(s, {
    text: "Result: Glucose = 95 mg/dL",
    eventDate: "2026-10-15",
  });
  assert.equal(s.sources.length, 2);
});
test("rejected source statements pause saved follow-through without erasing outreach", () => {
  const s = C.emptyState();
  source(s, "Referral to cardiology requested");
  const c = s.claims[0];
  C.review(s, c.id, "accepted");
  const t = C.tasks(s)[0];
  C.updateTask(s, t.id, { outreach: [{ at: C.now(), text: "Saved draft" }] });
  C.review(s, c.id, "rejected");
  assert.equal(C.tasks(s)[0].paused, true);
  assert.equal(C.tasks(s)[0].outreach[0].text, "Saved draft");
  C.review(s, c.id, "accepted");
  assert.equal(C.tasks(s)[0].status, "open");
});
test("reviewed appointments populate visit workspaces and pause on source correction", () => {
  const s = C.emptyState();
  const src = source(s, "Appointment scheduled 2026-11-01");
  const c = s.claims[0];
  assert.equal(C.visits(s).length, 0);
  C.review(s, c.id, "accepted");
  const v = C.visits(s)[0];
  assert.equal(v.date, "2026-11-01");
  C.updateVisit(s, v.id, { agenda: "My priorities" });
  C.review(s, c.id, "pending");
  assert.equal(C.visits(s)[0].paused, true);
  assert.equal(C.visits(s)[0].agenda, "My priorities");
  C.deleteSource(s, src.id);
  assert.equal(C.visits(s).length, 0);
});
test("cancelled tasks and appointments do not create open next steps or planned visits", () => {
  const s = C.emptyState();
  source(
    s,
    "Appointment canceled 2026-11-01\nReferral to cardiology cancelled",
  );
  s.claims.forEach((c) => C.review(s, c.id, "accepted"));
  assert.equal(C.visits(s).length, 0);
  assert.equal(C.tasks(s).length, 0);
});
