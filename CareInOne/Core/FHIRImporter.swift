import Foundation

public struct FHIRImport: Sendable { public var text: String; public var claims: [Claim]; public var skipped: Int; public var patientReference: String? }
public enum FHIRImporter {
    public static let version = "fhir-r4-subset-1.2"
    public static let supported = ["Condition", "AllergyIntolerance", "MedicationRequest", "MedicationStatement", "Observation", "ServiceRequest", "Procedure", "Appointment", "CarePlan"]
    public static func parse(_ data: Data, sourceID: UUID, eventAt: Date? = nil) throws -> FHIRImport {
        guard data.count <= 20_000_000, let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CareError.invalid("FHIR must be a JSON resource or Bundle smaller than 20 MB.") }
        let entries: [[String: Any]]
        if root["resourceType"] as? String == "Bundle" { entries = root["entry"] as? [[String: Any]] ?? [] }
        else { entries = [["resource": root]] }
        guard entries.count <= 2000 else { throw CareError.invalid("This FHIR file has more than 2,000 resources. Split it before importing.") }
        let patients = entries.filter { ($0["resource"] as? [String: Any])?["resourceType"] as? String == "Patient" }
        guard patients.count <= 1 else { throw CareError.invalid("This file contains multiple patients. Import a single-patient export.") }
        var patientRefs = Set<String>()
        if let patient = patients.first {
            if let id = (patient["resource"] as? [String: Any])?["id"] as? String { patientRefs.insert("Patient/" + id) }
            if let full = patient["fullUrl"] as? String { patientRefs.insert(full) }
        }
        // A Patient resource is optional, but multiple explicit patient identities are not.
        var referencedPatients = Set<String>()
        for entry in entries {
            guard let resource = entry["resource"] as? [String: Any],
                  let type = resource["resourceType"] as? String, supported.contains(type) else { continue }
            let subject = resource["subject"] as? [String: Any] ?? resource["patient"] as? [String: Any]
            var references = [subject?["reference"] as? String].compactMap { $0 }
            if type == "Appointment" {
                references += (resource["participant"] as? [[String: Any]] ?? []).compactMap {
                    let actor = $0["actor"] as? [String: Any]
                    guard let ref = actor?["reference"] as? String,
                          ref.contains("Patient/") || actor?["type"] as? String == "Patient" || patientRefs.contains(ref) else { return nil }
                    return ref
                }
            }
            for ref in references where ref.contains("Patient/") || ref.hasPrefix("urn:") {
                referencedPatients.insert(patientRefs.contains(ref) ? "known-patient" : ref)
            }
        }
        guard referencedPatients.count <= 1 else { throw CareError.invalid("This file references multiple patients. Import a single-patient export.") }
        var lines: [String] = [], claims: [Claim] = []; var skipped = 0
        for (index, entry) in entries.enumerated() {
            guard let r = entry["resource"] as? [String: Any], let type = r["resourceType"] as? String else { skipped += 1; continue }
            if type == "Patient" { continue }
            guard supported.contains(type) else { skipped += 1; continue }
            let concept = (r["medicationCodeableConcept"] ?? r["code"]) as? [String: Any] ?? [:]
            let coding = (concept["coding"] as? [[String: Any]])?.first ?? [:]
            let label = concept["text"] as? String ?? coding["display"] as? String ?? r["description"] as? String ?? r["title"] as? String ?? "\(type) (name not provided)"
            let status = r["status"] as? String ?? ((r["clinicalStatus"] as? [String: Any])?["coding"] as? [[String: Any]])?.first?["code"] as? String ?? "unknown"
            let intent = r["intent"] as? String
            let subject = r["subject"] as? [String: Any] ?? r["patient"] as? [String: Any]
            let participantRefs = (r["participant"] as? [[String:Any]] ?? []).compactMap { ($0["actor"] as? [String:Any])?["reference"] as? String }
            if !patientRefs.isEmpty && participantRefs.contains(where: { $0.contains("Patient/") && !patientRefs.contains($0) }) { throw CareError.invalid("This appointment references another patient. Import a single-patient source.") }
            let reference = subject?["reference"] as? String ?? participantRefs.first(where:patientRefs.contains)
            if let reference, !patientRefs.isEmpty, !patientRefs.contains(reference), reference.contains("Patient/") || reference.hasPrefix("urn:") { throw CareError.invalid("The export contains a reference to a different or unverified patient.") }
            var kind: EntityKind; var action: ClaimAction = .mentioned
            switch type {
            case "Condition": kind = .condition
            case "AllergyIntolerance": kind = .allergy
            case "MedicationRequest": kind = .medication; action = ["stopped", "cancelled"].contains(status) ? .stopped : status == "active" ? .ordered : .mentioned
            case "MedicationStatement": kind = .medication; action = ["stopped", "completed"].contains(status) ? .stopped : status == "active" ? .taking : status == "intended" ? .planned : .mentioned
            case "Observation": kind = .resultType; action = ["final", "amended", "corrected"].contains(status) ? .resultAvailable : .mentioned
            case "ServiceRequest":
                let categories = r["category"] as? [[String:Any]] ?? []
                let categoryNames = categories.flatMap { category in [category["text"] as? String ?? ""] + ((category["coding"] as? [[String:Any]]) ?? []).compactMap { $0["display"] as? String } }.joined(separator:" ").lowercased()
                let categoryCodes = categories.flatMap { ($0["coding"] as? [[String:Any]]) ?? [] }.compactMap { $0["code"] as? String }
                if coding["system"] as? String == "http://loinc.org" || categoryCodes.contains("108252007") || categoryNames.contains("laboratory") || categoryNames.contains("imaging") { kind = .labTest }
                else if categoryNames.contains("referral") { kind = .referral }
                else if categoryNames.contains("procedure") || categoryNames.contains("surgery") { kind = .procedure }
                else { kind = .other }
                action = ["active", "on-hold"].contains(status) ? (kind == .referral ? .requested : .ordered) : status == "completed" ? .completed : .mentioned
            case "Procedure": kind = .procedure; action = status == "completed" ? .completed : status == "preparation" ? .planned : .mentioned
            case "Appointment": kind = .appointment; action = ["booked", "arrived", "checked-in"].contains(status) ? .scheduled : ["cancelled", "noshow", "entered-in-error"].contains(status) ? .dismissed : .mentioned
            default: kind = .instruction
            }
            let dosages = (r["dosageInstruction"] ?? r["dosage"]) as? [[String: Any]] ?? []
            let dosage = dosages.first ?? [:]
            let rates = dosage["doseAndRate"] as? [[String: Any]] ?? []
            let complexDose = dosages.count > 1 || rates.count > 1 || rates.first?["doseRange"] != nil
            let dose = complexDose ? nil : rates.first?["doseQuantity"] as? [String: Any]
            func display(_ concept: [String: Any]?) -> String {
                concept?["text"] as? String ?? (concept?["coding"] as? [[String: Any]])?.first?["display"] as? String ?? ""
            }
            let route = dosages.count <= 1 ? display(dosage["route"] as? [String: Any]) : ""
            let timing = dosage["timing"] as? [String: Any] ?? [:]
            let frequency = dosages.count <= 1 ? display(timing["code"] as? [String: Any]) : ""
            var details = dosages.compactMap { $0["text"] as? String }
            if !route.isEmpty { details.append("route: " + route) }
            if !frequency.isEmpty { details.append("frequency: " + frequency) }
            let asNeeded = dosages.contains { $0["asNeededBoolean"] as? Bool == true || $0["asNeededCodeableConcept"] != nil }
            if asNeeded { details.append("as needed") }
            if complexDose { details.append("complex dosage: review original JSON") }
            for reaction in r["reaction"] as? [[String: Any]] ?? [] {
                let manifestations = (reaction["manifestation"] as? [[String: Any]] ?? []).map { display($0) }.filter { !$0.isEmpty }
                if !manifestations.isEmpty { details.append("reaction: " + manifestations.joined(separator: ", ")) }
                if let severity = reaction["severity"] as? String { details.append("reaction severity: " + severity) }
                if let description = reaction["description"] as? String { details.append(description) }
            }
            let quantity = r["valueQuantity"] as? [String: Any] ?? dose ?? [:]
            let numeric = quantity["value"] as? Double
            let unit = quantity["unit"] as? String ?? quantity["code"] as? String ?? ""
            let value = ([r["valueString"] as? String ?? display(r["valueCodeableConcept"] as? [String: Any])] + details).filter { !$0.isEmpty }.joined(separator: "; ")
            let dateString = r["effectiveDateTime"] as? String ?? r["onsetDateTime"] as? String ?? r["authoredOn"] as? String ?? r["performedDateTime"] as? String ?? r["start"] as? String
            let intentText = ["MedicationRequest", "ServiceRequest"].contains(type) ? "; intent: \(intent ?? "not provided")" : ""
            let text = "[entry \(index), \(type)/\(r["id"] as? String ?? "unknown")] \(label); status: \(status)" + intentText + (numeric.map { "; value: \($0) \(unit)" } ?? "") + (value.isEmpty ? "" : "; \(value)") + (dateString.map { "; date: \($0)" } ?? "")
            var c = Claim(sourceID: sourceID, kind: kind, label: String(label.prefix(200)), quote: text)
            c.route = route; c.frequency = frequency
            c.action = action; c.numericValue = numeric; c.unit = unit; c.value = value; c.provenance = .documentDerived; c.certainty = .documented; c.confidence = 0.95
            c.subject = reference.map { patientRefs.contains($0) ? .patient : .unknown } ?? .unknown
            c.eventAt = dateString.flatMap(DateParser.parse) ?? eventAt
            if kind == .appointment { c.dueAt = dateString.flatMap(DateParser.parse); c.duePrecision = c.dueAt == nil ? .unknown : .exact; c.dueTimeKnown = dateString?.contains("T") == true }
            if ["resolved", "inactive", "completed", "entered-in-error"].contains(status), [.condition, .medication, .allergy].contains(kind) { c.certainty = .historical }
            if status == "refuted" { c.negated = true }
            let verification = ((r["verificationStatus"] as? [String:Any])?["coding"] as? [[String:Any]])?.first?["code"] as? String
            if verification == "refuted" || status == "not-taken" { c.negated = true }
            if status == "entered-in-error" || verification == "entered-in-error" || (type == "Appointment" && status == "fulfilled") { c.certainty = .historical }
            if ["unconfirmed", "provisional", "differential"].contains(verification ?? "") || ["on-hold", "preliminary", "registered", "pending", "waitlist"].contains(status) { c.certainty = .uncertain }
            if status == "unknown" { c.certainty = .unknown }
            c.conditional = intent == "proposal" || intent == "option"
            if r["doNotPerform"] as? Bool == true { c.negated = true }
            if (type == "MedicationStatement" && status == "intended") || (type == "Appointment" && status == "proposed") { c.conditional = true; c.certainty = .conditional }
            let orderIntent = ["order", "original-order", "reflex-order", "filler-order", "instance-order"].contains(intent ?? "")
            if ["MedicationRequest", "ServiceRequest"].contains(type), !orderIntent { c.action = .mentioned }
            if type == "MedicationRequest", !orderIntent {
                // In FHIR, active describes the request lifecycle, not whether
                // this is an order. Plans/proposals must not become prescriptions.
                if ["plan", "proposal", "option"].contains(intent ?? "") {
                    c.conditional = true
                    if c.certainty == .documented { c.certainty = .conditional }
                    c.clarification = "This source describes a medication plan or proposal, not a confirmed order. Review the original intent with your treating team."
                } else {
                    c.confidence = 0.5
                    if c.certainty == .documented { c.certainty = .uncertain }
                    c.clarification = "This medication request has no supported order intent. No prescription or cessation has been inferred; review the original JSON."
                }
            }
            if type == "ServiceRequest" && kind == .other { c.confidence = 0.5; c.clarification = "What kind of service was requested? Review the category before tracking follow-through." }
            if asNeeded { c.conditional = true }
            if complexDose { c.confidence = 0.5; c.clarification = "This source has a complex dosage. Review the original instructions; no single dose has been inferred." }
            if label.contains("name not provided") { c.confidence = 0.5 }
            c.code = coding["code"] as? String; c.codeSystem = coding["system"] as? String; c.extractionVersion = version
            lines.append(text); claims.append(c)
        }
        guard !claims.isEmpty else { throw CareError.invalid("No supported clinical resources found. Supported: \(supported.joined(separator: ", ")). The original file can still be saved.") }
        return FHIRImport(text: lines.joined(separator: "\n"), claims: claims, skipped: skipped, patientReference: patientRefs.sorted().first)
    }
}
