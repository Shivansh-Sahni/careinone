import { validateState } from "./core.js";
export const revision = (value) =>
  Number.isSafeInteger(value?._revision) && value._revision >= 0
    ? value._revision
    : 0;
const DB = "careinone-web-v1";
const channel =
  typeof BroadcastChannel !== "undefined"
    ? new BroadcastChannel("careinone-web")
    : null;
channel?.unref?.(); // Node test runners do not need to keep a channel alive.
export const subscribe = (callback) =>
  channel?.addEventListener("message", callback);
const open = () =>
  new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore("vault");
    req.onsuccess = () => resolve(req.result);
    req.onerror = () =>
      reject(
        Error("Browser storage is unavailable. Enable storage for this site."),
      );
  });
async function transaction(mode, operation) {
  const db = await open();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction("vault", mode);
      const req = operation(tx.objectStore("vault"));
      let result;
      req.onsuccess = () => {
        result = req.result;
      };
      tx.oncomplete = () => resolve(result);
      tx.onerror = () =>
        reject(
          Error(
            "Records could not be saved. Storage may be full. Export a backup before continuing.",
          ),
        );
      tx.onabort = () => reject(Error("Storage transaction failed."));
    });
  } finally {
    db.close();
  }
}
export const load = () => transaction("readonly", (s) => s.get("state"));
export async function save(state, expected = revision(state)) {
  validateState(state);
  if (new TextEncoder().encode(JSON.stringify(state)).byteLength > 40000000)
    throw Error(
      "This workspace exceeds the 40 MB web storage limit. Export a backup, then remove unneeded original attachments.",
    );
  const db = await open();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction("vault", "readwrite"),
        store = tx.objectStore("vault");
      const get = store.get("state");
      let conflict = false;
      get.onsuccess = () => {
        if (revision(get.result) !== expected) {
          conflict = true;
          tx.abort();
          return;
        }
        store.put({ ...state, _revision: expected + 1 }, "state");
      };
      tx.oncomplete = () => {
        state._revision = expected + 1;
        channel?.postMessage("saved");
        resolve();
      };
      tx.onerror = () =>
        reject(
          Error(
            "Records could not be saved. Export a backup before continuing.",
          ),
        );
      tx.onabort = () =>
        reject(
          Error(
            conflict
              ? "Records changed in another tab. Reload before saving."
              : "Storage transaction failed.",
          ),
        );
    });
  } finally {
    db.close();
  }
}
export async function clear(expected) {
  const db = await open();
  try {
    await new Promise((resolve, reject) => {
      const tx = db.transaction("vault", "readwrite"),
        store = tx.objectStore("vault"),
        request = store.get("state");
      request.onsuccess = () => {
        if (revision(request.result) !== expected) {
          tx.abort();
          return;
        }
        store.clear();
      };
      tx.oncomplete = resolve;
      tx.onabort = () =>
        reject(
          Error("Records changed in another tab. Reload before clearing."),
        );
      tx.onerror = () => reject(Error("Records could not be cleared."));
    });
    channel?.postMessage("cleared");
  } finally {
    db.close();
  }
}
const encode = (bytes) => {
  let result = "";
  for (let i = 0; i < bytes.length; i += 8192)
    result += String.fromCharCode(...bytes.subarray(i, i + 8192));
  return btoa(result);
};
const decode = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
async function derive(password, salt) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveKey"],
  );
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 600000 },
    key,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}
export async function encrypt(state, password) {
  if (password.length < 12)
    throw Error("Use a backup passphrase of at least 12 characters.");
  const salt = crypto.getRandomValues(new Uint8Array(16)),
    iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    await derive(password, salt),
    new TextEncoder().encode(JSON.stringify(validateState(state))),
  );
  return JSON.stringify({
    format: "careinone-encrypted-1",
    kdf: "PBKDF2-SHA256-600000",
    salt: encode(salt),
    iv: encode(iv),
    data: encode(new Uint8Array(ciphertext)),
  });
}
export async function decrypt(text, password) {
  try {
    const box = JSON.parse(text);
    if (
      box.format !== "careinone-encrypted-1" ||
      box.kdf !== "PBKDF2-SHA256-600000" ||
      text.length > 60000000
    )
      throw Error();
    const salt = decode(box.salt),
      iv = decode(box.iv);
    if (salt.length !== 16 || iv.length !== 12) throw Error();
    const bytes = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv },
      await derive(password, salt),
      decode(box.data),
    );
    return validateState(JSON.parse(new TextDecoder().decode(bytes)));
  } catch {
    throw Error(
      "Could not restore: incorrect passphrase, damaged file, or unsupported backup.",
    );
  }
}
