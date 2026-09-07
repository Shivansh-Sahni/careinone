import Foundation

public struct FHIRImport: Sendable { public var text: String; public var claims: [Claim]; public var skipped: Int; public var patientReference: String? }
public enum FHIRImporter {
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
        var lines: [String] = [], claims: [Claim] = []; var skipped = 0
        for (index, entry) in entries.enumerated() {
            guard let r = entry["resource"] as? [String: Any], let type = r["resourceType"] as? String else { skipped += 1; continue }
            if type == "Patient" { continue }
            guard supported.contains(type) else { skipped += 1; continue }
            let concept = (r["medicationCodeableConcept"] ?? r["code"]) as? [String: Any] ?? [:]
            let coding = (concept["coding"] as? [[String: Any]])?.first ?? [:]
            let label = concept["text"] as? String ?? coding["display"] as? String ?? r["description"] as? String ?? r["title"] as? String ?? "\(type) (name not provided)"
            let status = r["status"] as? String ?? ((r["clinicalStatus"] as? [String: Any])?["coding"] as? [[String: Any]])?.first?["code"] as? String ?? "unknown"
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
            let dose = (((r["dosageInstruction"] ?? r["dosage"]) as? [[String: Any]])?.first?["doseAndRate"] as? [[String: Any]])?.first?["doseQuantity"] as? [String: Any]
            let quantity = r["valueQuantity"] as? [String: Any] ?? dose ?? [:]
            let numeric = quantity["value"] as? Double
            let unit = quantity["unit"] as? String ?? quantity["code"] as? String ?? ""
            let value = r["valueString"] as? String ?? ""
            let dateString = r["effectiveDateTime"] as? String ?? r["onsetDateTime"] as? String ?? r["authoredOn"] as? String ?? r["performedDateTime"] as? String ?? r["start"] as? String
            let text = "[entry \(index), \(type)/\(r["id"] as? String ?? "unknown")] \(label); status: \(status)" + (numeric.map { "; value: \($0) \(unit)" } ?? "") + (value.isEmpty ? "" : "; \(value)") + (dateString.map { "; date: \($0)" } ?? "")
            var c = Claim(sourceID: sourceID, kind: kind, label: String(label.prefix(200)), quote: text)
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
            c.conditional = (r["intent"] as? String) == "proposal" || (r["intent"] as? String) == "option"
            if r["doNotPerform"] as? Bool == true { c.negated = true }
            if (type == "MedicationStatement" && status == "intended") || (type == "Appointment" && status == "proposed") { c.conditional = true; c.certainty = .conditional }
            if type == "ServiceRequest", !["order", "original-order", "reflex-order", "filler-order", "instance-order"].contains(r["intent"] as? String ?? "") { c.action = .mentioned }
            if type == "ServiceRequest" && kind == .other { c.confidence = 0.5; c.clarification = "What kind of service was requested? Review the category before tracking follow-through." }
            if label.contains("name not provided") { c.confidence = 0.5 }
            c.code = coding["code"] as? String; c.codeSystem = coding["system"] as? String; c.extractionVersion = "fhir-r4-subset-1.0"
            lines.append(text); claims.append(c)
        }
        guard !claims.isEmpty else { throw CareError.invalid("No supported clinical resources found. Supported: \(supported.joined(separator: ", ")). The original file can still be saved.") }
        return FHIRImport(text: lines.joined(separator: "\n"), claims: claims, skipped: skipped, patientReference: patientRefs.sorted().first)
    }
}
