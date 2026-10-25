import test from "node:test";
import assert from "node:assert/strict";
import { importFHIR } from "../public/imports.js";
import * as C from "../public/core.js";
const bundle = (resources) =>
  JSON.stringify({
    resourceType: "Bundle",
    entry: resources.map((resource) => ({
      resource,
      fullUrl: `urn:uuid:${resource.id}`,
    })),
  });
test("FHIR import preserves numeric units and single-patient attribution without external fetches", () => {
  const result = importFHIR(
    bundle([
      { resourceType: "Patient", id: "p" },
      {
        resourceType: "Observation",
        id: "o",
        subject: { reference: "Patient/p" },
        code: { text: "Fictional glucose" },
        status: "final",
        valueQuantity: { value: 95, unit: "mg/dL" },
        effectiveDateTime: "2026-10-01",
      },
    ]),
  );
  assert.equal(result.proposals[0].subject, "patient");
  assert.equal(result.proposals[0].value, "95 mg/dL");
  assert.equal(result.proposals[0].eventDate, "2026-10-01");
  const s = C.emptyState();
  C.addSource(
    s,
    { title: "FHIR", text: result.text, kind: "fhir" },
    result.proposals,
  );
  assert.equal(s.claims[0].review, "pending");
  assert.ok(s.sources[0].text.includes(s.claims[0].quote));
});
test("FHIR unresolved subject is unknown and never promoted to personal care", () => {
  const result = importFHIR(
    bundle([
      {
        resourceType: "Observation",
        id: "o",
        subject: { reference: "https://external.test/Patient/other" },
        code: { text: "Glucose" },
        valueQuantity: { value: 100, unit: "mg/dL" },
      },
    ]),
  );
  assert.equal(result.proposals[0].subject, "unknown");
  const s = C.emptyState();
  C.addSource(s, { text: result.text }, result.proposals);
  C.review(s, s.claims[0].id, "accepted");
  assert.equal(C.project(s).length, 0);
});
test("FHIR multiple patients are rejected rather than mixed", () =>
  assert.throws(
    () =>
      importFHIR(
        bundle([
          { resourceType: "Patient", id: "p1" },
          { resourceType: "Patient", id: "p2" },
        ]),
      ),
    /multiple patients/,
  ));
test("FHIR unsupported resources and narrative markup never become fabricated claims", () => {
  assert.throws(
    () =>
      importFHIR(
        bundle([
          {
            resourceType: "DocumentReference",
            text: { div: "<script>bad()</script>" },
          },
        ]),
      ),
    /No supported/,
  );
});
test("FHIR rejects nonfinite observations and invalid JSON", () => {
  assert.throws(() => importFHIR("not json"), /valid FHIR/);
  assert.throws(
    () =>
      importFHIR(
        bundle([
          {
            resourceType: "Observation",
            code: { text: "Test" },
            valueQuantity: { value: "bad" },
          },
        ]),
      ),
    /numeric/,
  );
});
test("PDF page provenance is preserved for exact unchanged text and discarded when unverified", () => {
  const s = C.emptyState();
  C.addSource(s, {
    title: "PDF",
    text: "CBC ordered\n\nCondition: example",
    kind: "pdf",
    pages: [
      { number: 1, text: "CBC ordered" },
      { number: 2, text: "Condition: example" },
    ],
  });
  assert.equal(s.claims[0].page, 1);
  assert.equal(s.claims[1].page, 2);
  const claim = C.makeClaim(
    { kind: "other", label: "Example", quote: "CBC ordered", page: 2 },
    s.sources[0],
  );
  assert.equal(claim.page, null);
});
test("a preserved original can be captured without invented extracted text", () => {
  const s = C.emptyState();
  C.addSource(s, {
    title: "Untranscribed original",
    text: "",
    kind: "photo",
    attachment: {
      name: "test.png",
      type: "image/png",
      data: "data:image/png;base64,AA==",
    },
  });
  assert.equal(s.claims.length, 0);
  assert.equal(C.validateState(s), s);
});

test("leading and trailing page whitespace cannot invalidate an otherwise exact source quote", () => {
  const s = C.emptyState();
  C.addSource(s, {
    title: "PDF",
    text: "  CBC ordered  \n",
    kind: "pdf",
    pages: [{ number: 1, text: "  CBC ordered  \n" }],
  });
  assert.equal(s.claims[0].quote, "CBC ordered");
  assert.equal(s.claims[0].page, 1);
  assert.equal(C.validateState(s), s);
});
