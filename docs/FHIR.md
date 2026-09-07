# Supported patient-owned FHIR JSON

The importer supports a single resource or a FHIR R4 JSON Bundle with at most one Patient and 2,000 entries. File limits: 20 MB for FHIR parsing, within the 30 MB general evidence limit. Multiple Patient resources are rejected. Explicit mismatching patient references in a single-patient bundle are rejected; absent/unverified subjects remain unknown and require patient attribution during review.

| Resource | Local representation |
|---|---|
| Condition | Condition, coded label, clinical status, onset date |
| AllergyIntolerance | Allergy, coded label, status; refutation as negation |
| MedicationRequest | Medication proposal, medicationCodeableConcept, simple dose quantity, authored date, reported status |
| MedicationStatement | Patient medication report from the document, simple dose quantity/status/effective date |
| Observation | Result, coded label, simple valueQuantity/valueString, status, effective date |
| ServiceRequest | Test for explicit LOINC/laboratory/imaging classification, referral or procedure for explicit category; otherwise an uncertain-category proposal requiring review. Intent must be an explicit order before an actionable loop is possible. |
| Procedure | Procedure status and performed date |
| Appointment | Appointment description/status/start; verifies a known Patient participant; cancellation/no-show is dismissed, fulfilled is historical, proposed remains conditional |
| CarePlan | Instruction/title; complex activities are not expanded into inferred actions |

Original JSON is preserved byte-for-byte as an evidence attachment. Working text is a deterministic rendering of supported fields and includes the bundle entry index and resource type/ID. Proposal quotes are exact spans in that rendering; the original JSON remains available for inspection. Unsupported resources remain only in the original file and their count is shown.

This is a conservative importer, not a complete FHIR implementation. It does not resolve remote references, perform terminology lookups, assume resource types imply the patient, normalize complex medication timing, process arbitrary extensions, or connect to an EHR. Unknown medication names are not silently matched. Use the structured review editor to correct labels, dates, subject, units, and associations from the preserved original.

FHIR source retry/re-analysis reads the preserved original file locally. Editing its event date retires previous source claims until renewed review. The generated FHIR working rendering cannot be edited directly in the source editor; claims can be edited during review.

MedicationStatement `active` maps to reported taking; `not-taken` is negated, `intended` is conditional/planned, `on-hold` is uncertain, and unknown remains unknown. Refuted Condition/Allergy verification is negated. These mappings follow the [FHIR R4 medication status definitions](https://hl7.org/fhir/R4/valueset-medication-statement-status.html) and [appointment status definitions](https://hl7.org/fhir/R4/valueset-appointmentstatus.html). ServiceRequest can represent several service types, so the importer does not assume every request is a test. [FHIR R4 ServiceRequest](https://hl7.org/fhir/R4/servicerequest.html).

After patient acceptance, a final result can contribute to an existing test loop through a unique exact code/system match or a patient-reviewed `resultOf`/`completes` relationship. Its result entity and original claim remain separate. Existing chronology and uncertainty rules still govern loop closure; fuzzy labels never close a test automatically. Complex panel/component interpretation and remote reference resolution are not implemented.

Try [the synthetic single-patient fixture](../Tests/Fixtures/synthetic-patient.fhir.json) through Files/Open In or the FHIR capture action. It includes an order, its final coded result, and an appointment. The automated fixture test verifies that nothing enters care memory until review and that the accepted coded result closes the matching test loop.
