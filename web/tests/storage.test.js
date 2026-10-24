import "fake-indexeddb/auto";
import test from "node:test";
import assert from "node:assert/strict";
import * as storage from "../public/storage.js";
import { emptyState, addSource } from "../public/core.js";
test.beforeEach(async () => {
  const current = await storage.load();
  await storage.clear(storage.revision(current));
});
test("a durable save advances revision only after commit and survives reopening", async () => {
  const state = emptyState();
  addSource(state, { text: "A fictional note" });
  await storage.save(state);
  assert.equal(state._revision, 1);
  assert.deepEqual(await storage.load(), state);
});
test("a stale save and repeated retry preserve both the winning state and caller revision", async () => {
  const initial = emptyState();
  await storage.save(initial);
  const a = structuredClone(initial),
    b = structuredClone(initial);
  a.profile.name = "Winning update";
  await storage.save(a);
  b.profile.name = "Stale update";
  await assert.rejects(() => storage.save(b), /another tab/);
  assert.equal(b._revision, 1);
  await assert.rejects(() => storage.save(b), /another tab/);
  assert.equal((await storage.load()).profile.name, "Winning update");
  assert.equal((await storage.load())._revision, 2);
});
test("concurrent IndexedDB transactions permit one writer per expected revision", async () => {
  const initial = emptyState();
  await storage.save(initial);
  const a = structuredClone(initial),
    b = structuredClone(initial);
  a.profile.name = "A";
  b.profile.name = "B";
  const results = await Promise.allSettled([storage.save(a), storage.save(b)]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  assert.equal((await storage.load())._revision, 2);
});
test("failed validation does not mutate the stored workspace", async () => {
  const state = emptyState();
  await storage.save(state);
  const bad = structuredClone(state);
  bad.sources.push({ id: "invalid" });
  await assert.rejects(() => storage.save(bad));
  assert.deepEqual(await storage.load(), state);
});
test("stale clearing is rejected and current clearing permits a fresh workspace", async () => {
  const state = emptyState();
  await storage.save(state);
  await assert.rejects(() => storage.clear(0), /another tab/);
  assert.deepEqual(await storage.load(), state);
  await storage.clear(1);
  assert.equal(await storage.load(), undefined);
  const fresh = emptyState();
  await storage.save(fresh);
  assert.equal(fresh._revision, 1);
});
test("restoring a snapshot uses the current revision instead of trusting backup metadata", async () => {
  const old = emptyState();
  await storage.save(old);
  const restored = emptyState();
  restored._revision = 999;
  restored.profile.name = "Restored";
  await storage.save(restored, old._revision);
  assert.equal(restored._revision, 2);
  assert.equal((await storage.load()).profile.name, "Restored");
});
test("legacy and malformed revisions normalize without inheriting attacker values", () => {
  assert.equal(storage.revision(undefined), 0);
  assert.equal(storage.revision({ _revision: "99" }), 0);
  assert.equal(storage.revision({ _revision: -1 }), 0);
  assert.equal(storage.revision({ _revision: 7 }), 7);
});
