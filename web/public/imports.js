// All document parsing and English OCR run on this browser, using self-hosted assets.
import { validDate } from "./core.js";
const PDF = "/vendor/pdf-5.5.207",
  OCR = "/vendor/ocr-7.0.0";
const aborted = (signal) => {
  if (signal?.aborted) throw new DOMException("Import cancelled", "AbortError");
};
async function recognize(image, { onProgress = () => {}, signal } = {}) {
  aborted(signal);
  const { default: Tesseract } = await import(`${OCR}/tesseract.esm.min.js`);
  const { createWorker } = Tesseract;
  const worker = await createWorker("eng", 1, {
    workerPath: `${OCR}/worker.min.js`,
    corePath: `${OCR}/core`,
    langPath: `${OCR}/lang`,
    workerBlobURL: false,
    cacheMethod: "write",
    logger: (m) =>
      onProgress(
        `${m.status || "Reading image"}${typeof m.progress === "number" ? ` · ${Math.round(m.progress * 100)}%` : ""}`,
      ),
  });
  const cancel = () => {
    void worker.terminate();
  };
  signal?.addEventListener("abort", cancel, { once: true });
  try {
    aborted(signal);
    const result = await worker.recognize(image);
    aborted(signal);
    return result.data.text;
  } finally {
    signal?.removeEventListener("abort", cancel);
    await worker.terminate();
  }
}
export async function importDocument(file, options = {}) {
  if (file.size > 5 * 1024 * 1024)
    throw Error(
      "Choose a file under 5 MB. Split larger documents into smaller files.",
    );
  const { onProgress = () => {}, signal } = options;
  aborted(signal);
  if (
    file.name.toLowerCase().endsWith(".json") ||
    file.type === "application/json"
  )
    return importFHIR(await file.text());
  if (file.type === "text/plain" || file.name.toLowerCase().endsWith(".txt"))
    return { text: await file.text(), kind: "textFile", pages: [] };
  if (file.type.startsWith("image/")) {
    const bitmap = await createImageBitmap(file);
    const pixels = bitmap.width * bitmap.height;
    bitmap.close();
    if (pixels > 25000000)
      throw Error("Use an image smaller than 25 megapixels.");
    const text = await recognize(file, options);
    return { text, kind: "photo", pages: [{ number: 1, text }] };
  }
  if (
    file.type === "application/pdf" ||
    file.name.toLowerCase().endsWith(".pdf")
  ) {
    const pdf = await import(`${PDF}/pdf.mjs`);
    pdf.GlobalWorkerOptions.workerSrc = `${PDF}/pdf.worker.mjs`;
    const task = pdf.getDocument({
      data: new Uint8Array(await file.arrayBuffer()),
      isEvalSupported: false,
      enableXfa: false,
      cMapUrl: `${PDF}/cmaps/`,
      cMapPacked: true,
      standardFontDataUrl: `${PDF}/standard_fonts/`,
      wasmUrl: `${PDF}/wasm/`,
      stopAtErrors: true,
    });
    const cancel = () => {
      void task.destroy();
    };
    signal?.addEventListener("abort", cancel, { once: true });
    let document;
    try {
      document = await task.promise;
      if (document.numPages > 50)
        throw Error(
          "This PDF has more than 50 pages. Split it into smaller documents.",
        );
      const pages = [];
      let scanned = 0;
      for (let n = 1; n <= document.numPages; n++) {
        aborted(signal);
        onProgress(`Reading PDF page ${n} of ${document.numPages}`);
        const page = await document.getPage(n),
          content = await page.getTextContent();
        let text = content.items
          .map((item) => item.str + (item.hasEOL ? "\n" : " "))
          .join("")
          .trim();
        if (text.replace(/\s/g, "").length < 20) {
          if (++scanned > 10)
            throw Error(
              "Scanned PDFs are limited to 10 OCR pages per import. Split this document into smaller files.",
            );
          const natural = page.getViewport({ scale: 1 }),
            scale = Math.min(
              2,
              Math.sqrt(10000000 / (natural.width * natural.height)),
            ),
            view = page.getViewport({ scale });
          const canvas = documentCanvas(view.width, view.height);
          await page.render({
            canvasContext: canvas.getContext("2d"),
            viewport: view,
          }).promise;
          const blob = await new Promise((resolve) =>
            canvas.toBlob(resolve, "image/png"),
          );
          text = await recognize(blob, {
            ...options,
            onProgress: (status) =>
              onProgress(`Page ${n}/${document.numPages} · ${status}`),
          });
          canvas.width = 0;
          canvas.height = 0;
        }
        pages.push({ number: n, text });
        page.cleanup();
      }
      const text = pages.map((p) => p.text).join("\n\n");
      if (text.length > 200000)
        throw Error(
          "Extracted text exceeds 200,000 characters. Split the document.",
        );
      return { text, kind: "pdf", pages };
    } catch (e) {
      if (e.name === "PasswordException")
        throw Error(
          "This PDF is password-protected. Unlock a copy locally before importing it.",
        );
      throw e;
    } finally {
      signal?.removeEventListener("abort", cancel);
      if (document) await document.destroy();
      else await task.destroy();
    }
  }
  throw Error("Choose a TXT, FHIR JSON, PDF, PNG, JPEG or WebP file.");
}
function documentCanvas(width, height) {
  const canvas = globalThis.document.createElement("canvas");
  canvas.width = Math.ceil(width);
  canvas.height = Math.ceil(height);
  return canvas;
}
const concept = (value) =>
  typeof value?.text === "string"
    ? value.text
    : (value?.coding || [])
        .map((c) => c.display)
        .filter((v) => typeof v === "string")
        .join(" / ");
const dateOnly = (value) =>
  typeof value === "string" && validDate(value.slice(0, 10))
    ? value.slice(0, 10)
    : "";
export function importFHIR(text) {
  let root;
  try {
    root = JSON.parse(text);
  } catch {
    throw Error("This is not valid FHIR JSON.");
  }
  const entries =
    root?.resourceType === "Bundle"
      ? (root.entry || []).map((e) => ({
          resource: e.resource,
          url: e.fullUrl,
        }))
      : [{ resource: root, url: "" }];
  if (!entries.length || entries.length > 500)
    throw Error("Use a FHIR resource or a bundle with at most 500 entries.");
  const patients = entries.filter(
    (e) => e.resource?.resourceType === "Patient",
  );
  if (patients.length > 1)
    throw Error(
      "This bundle includes multiple patients. Import one patient at a time.",
    );
  const patient = patients[0],
    patientRefs = new Set(
      patient
        ? [patient.url, `Patient/${patient.resource.id}`].filter(Boolean)
        : [],
    );
  const lines = [],
    proposals = [];
  let unsupported = 0;
  for (const entry of entries) {
    const r = entry.resource;
    if (!r || r.resourceType === "Patient") continue;
    let kind,
      action = "mentioned",
      label = "",
      value = "",
      frequency = "",
      numericValue = null,
      unit = "";
    const subjectRef = r.subject?.reference || r.patient?.reference;
    const subject = patientRefs.has(subjectRef) ? "patient" : "unknown";
    let certainty = "documented";
    switch (r.resourceType) {
      case "Condition":
        kind = "condition";
        label = concept(r.code);
        if (
          ["resolved", "inactive", "remission"].includes(
            r.clinicalStatus?.coding?.[0]?.code,
          )
        )
          certainty = "historical";
        break;
      case "AllergyIntolerance":
        kind = "allergy";
        label = concept(r.code);
        break;
      case "MedicationStatement":
      case "MedicationRequest":
        kind = "medication";
        label =
          concept(r.medicationCodeableConcept) ||
          r.medicationReference?.display ||
          "";
        value = (r.dosage || r.dosageInstruction || [])
          .map((d) => d.text)
          .filter((t) => typeof t === "string")
          .join("; ");
        action = ["stopped", "not-taken"].includes(r.status)
          ? "stopped"
          : r.status === "active"
            ? "taking"
            : "mentioned";
        if (r.status === "entered-in-error") certainty = "uncertain";
        break;
      case "Observation":
        kind = "resultType";
        label = concept(r.code);
        if (r.valueQuantity?.value != null) {
          if (
            typeof r.valueQuantity.value !== "number" ||
            !Number.isFinite(r.valueQuantity.value)
          )
            throw Error("Invalid numeric observation.");
          numericValue = r.valueQuantity.value;
          unit = r.valueQuantity.unit || r.valueQuantity.code || "";
          value = `${numericValue} ${unit}`.trim();
        } else
          value =
            typeof r.valueString === "string"
              ? r.valueString
              : concept(r.valueCodeableConcept);
        if (
          [
            "preliminary",
            "registered",
            "cancelled",
            "entered-in-error",
          ].includes(r.status)
        )
          certainty = "uncertain";
        break;
      case "ServiceRequest":
        kind = "labTest";
        label = concept(r.code);
        action =
          r.status === "active"
            ? "requested"
            : r.status === "completed"
              ? "completed"
              : "mentioned";
        break;
      case "Procedure":
        kind = "procedure";
        label = concept(r.code);
        action = r.status === "completed" ? "completed" : "mentioned";
        break;
      case "Appointment":
        kind = "appointment";
        label = r.description || concept(r.serviceType?.[0]) || "Appointment";
        action = r.status === "booked" ? "scheduled" : "mentioned";
        break;
      case "Practitioner":
        kind = "provider";
        label = (r.name || [])
          .map(
            (n) =>
              n.text ||
              [...(n.given || []), n.family].filter(Boolean).join(" "),
          )
          .join(" / ");
        break;
      default:
        unsupported++;
        continue;
    }
    if (
      ["entered-in-error", "cancelled", "refuted", "unknown"].includes(r.status)
    )
      certainty = "uncertain";
    if (
      r.resourceType === "AllergyIntolerance" &&
      ["resolved", "inactive"].includes(r.clinicalStatus?.coding?.[0]?.code)
    )
      certainty = "historical";
    if (!label || typeof label !== "string") {
      unsupported++;
      continue;
    }
    label = label.slice(0, 200);
    const eventDate = dateOnly(
        r.effectiveDateTime ||
          r.authoredOn ||
          r.onsetDateTime ||
          r.performedDateTime ||
          r.start,
      ),
      dueDate = kind === "appointment" ? dateOnly(r.start) : "";
    const quote = `${r.resourceType}${r.id ? ` [${r.id}]` : ""}: ${label}${value ? ` · ${value}` : ""}${r.status ? ` · status: ${r.status}` : ""}`;
    lines.push(quote);
    proposals.push({
      kind,
      label,
      value,
      numericValue,
      unit,
      frequency,
      action,
      subject,
      certainty,
      quote,
      eventDate,
      dueDate,
      duePrecision: dueDate ? "exact" : "unknown",
      extraction: "fhir-subset-web-1",
    });
    if (proposals.length >= 200)
      throw Error(
        "This import has too many supported resources. Split it into smaller bundles.",
      );
  }
  if (!proposals.length)
    throw Error(
      "No supported, labeled FHIR resources found. Supported: conditions, allergies, medications, observations, service requests, procedures, appointments and practitioners.",
    );
  return {
    text: lines.join("\n"),
    kind: "fhir",
    pages: [],
    proposals,
    notice: `${proposals.length} FHIR statements prepared; ${unsupported} unsupported or unlabeled resources skipped. Patient attribution is unknown unless it matches the bundle’s single Patient. External references are never fetched.`,
  };
}
