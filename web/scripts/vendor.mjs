// Copy only the explicitly used, pinned browser runtime assets. No CDN calls.
import { mkdir, copyFile, readdir, writeFile, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = fileURLToPath(new URL("..", import.meta.url)),
  output = path.join(root, "public/vendor");
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
const manifest = {};
async function copy(from, to) {
  const target = path.join(output, to);
  await mkdir(path.dirname(target), { recursive: true });
  await copyFile(path.join(root, "node_modules", from), target);
  manifest["/vendor/" + to] = "vendor/" + to;
}
for (const name of ["pdf.mjs", "pdf.worker.mjs"])
  await copy("pdfjs-dist/build/" + name, "pdf-5.5.207/" + name);
await copy("pdfjs-dist/LICENSE", "pdf-5.5.207/LICENSE");
for (const dir of ["standard_fonts", "cmaps", "wasm"])
  for (const file of await readdir(
    path.join(root, "node_modules/pdfjs-dist", dir),
  ))
    if (!file.endsWith(".map"))
      await copy(`pdfjs-dist/${dir}/${file}`, `pdf-5.5.207/${dir}/${file}`);
for (const file of [
  "tesseract.esm.min.js",
  "worker.min.js",
  "worker.min.js.LICENSE.txt",
  "tesseract.min.js.LICENSE.txt",
])
  await copy("tesseract.js/dist/" + file, "ocr-7.0.0/" + file);
await copy("tesseract.js/LICENSE.md", "ocr-7.0.0/LICENSE");
for (const file of await readdir(
  path.join(root, "node_modules/tesseract.js-core"),
))
  if (
    file.startsWith("tesseract-core") &&
    (file.endsWith(".wasm.js") || file.endsWith(".wasm"))
  )
    await copy("tesseract.js-core/" + file, "ocr-7.0.0/core/" + file);
await copy("tesseract.js-core/LICENSE", "ocr-7.0.0/core/LICENSE");
await copy(
  "@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz",
  "ocr-7.0.0/lang/eng.traineddata.gz",
);
await writeFile(
  path.join(root, "public/vendor-manifest.json"),
  JSON.stringify(manifest, null, 2) + "\n",
);
console.log(
  `Prepared ${Object.keys(manifest).length} self-hosted document assets.`,
);

// Preserve upstream notices alongside the self-hosted browser distributions.
const { readFile } = await import("node:fs/promises");
const notices = [
  [
    "PDF.js 5.5.207 — Mozilla / contributors (Apache-2.0)",
    "pdfjs-dist/LICENSE",
  ],
  [
    "Tesseract.js 7.0.0 — Naptha / contributors (Apache-2.0)",
    "tesseract.js/LICENSE.md",
  ],
  ["Tesseract.js core 7.0.0 — contributors", "tesseract.js-core/LICENSE"],
  [
    "English trained data 1.0.0 — tesseract-ocr / contributors",
    "@tesseract.js-data/eng/README.md",
  ],
];
let noticeText = "CareInOne Web — third-party browser components\n\n";
for (const [title, file] of notices)
  noticeText +=
    title +
    "\n\n" +
    (await readFile(path.join(root, "node_modules", file), "utf8")) +
    "\n\n";
await writeFile(path.join(root, "public/vendor-notices.txt"), noticeText);
