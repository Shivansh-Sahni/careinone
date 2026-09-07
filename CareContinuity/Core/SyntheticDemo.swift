import Foundation

public enum SyntheticDemo {
    public static func load(into state: inout CareState, now: Date = Date()) throws {
        guard !state.profile.demoLoaded else { return }
        let calendar = Calendar(identifier: .gregorian)
        func date(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: now)! }
        let pcp = EncounterRecord(title: "Synthetic · Primary care", date: date(-28), provider: "Dr. Morgan · Synthetic")
        let cardiology = EncounterRecord(title: "Synthetic · Cardiology", date: date(-7), provider: "Dr. Rivera · Synthetic")
        state.encounters += [pcp, cardiology]
        func add(_ title: String, _ text: String, _ days: Int, kind: EntityKind, label: String, action: ClaimAction = .mentioned, number: Double? = nil, unit: String = "", due: Date? = nil, encounter: EncounterRecord? = nil, reported: Bool = false) throws {
            var source = Source(title: "Synthetic · " + title, kind: reported ? .typed : .textFile, text: text, contentHash: ContentHasher.hash("demo|" + text), eventAt: date(days))
            source.synthetic = true; source.encounterID = encounter?.id; source.provider = encounter?.provider ?? ""; source.state = .complete; source.capturedAt = date(days)
            var claim = Claim(sourceID: source.id, kind: kind, label: label, quote: text)
            claim.action = action; claim.numericValue = number; claim.unit = unit; claim.eventAt = source.eventAt; claim.dueAt = due; claim.duePrecision = due == nil ? .unknown : .exact
            claim.dueTimeKnown = kind == .appointment && due != nil
            claim.certainty = reported ? .reported : .documented; claim.provenance = reported ? .patientReported : .documentDerived; claim.confidence = 1
            if kind == .medication { claim.frequency = "daily"; claim.route = "oral" }
            state.sources.append(source); try Reconciler.accept([claim], into: &state, now: date(days))
        }
        try add("PCP medication list", "Metoprolol succinate 25 mg oral daily.", -28, kind: .medication, label: "Metoprolol succinate", action: .taking, number: 25, unit: "mg", encounter: pcp)
        try add("Cardiology instructions", "Metoprolol succinate 50 mg oral daily.", -7, kind: .medication, label: "Metoprolol succinate", action: .changed, number: 50, unit: "mg", encounter: cardiology)
        try add("My medication update", "I report taking metoprolol succinate 50 mg oral daily.", -1, kind: .medication, label: "Metoprolol succinate", action: .taking, number: 50, unit: "mg", reported: true)
        try add("Lab order", "CBC ordered; please complete in three days.", -1, kind: .labTest, label: "CBC", action: .ordered, due: date(2), encounter: cardiology)
        try add("Referral", "Referral to physical therapy placed.", -7, kind: .referral, label: "Physical therapy", action: .referralPlaced, encounter: cardiology)
        try add("Appointment card", "Primary care follow-up appointment in four days at 10 AM.", -1, kind: .appointment, label: "Primary care follow-up", action: .scheduled, due: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date(4)), encounter: pcp)
        try add("Older result", "Hemoglobin 12.8 g/dL; final result.", -90, kind: .resultType, label: "Hemoglobin", action: .resultAvailable, number: 12.8, unit: "g/dL", encounter: pcp)
        try add("Recent result", "Hemoglobin 13.1 g/dL; final result.", -7, kind: .resultType, label: "Hemoglobin", action: .resultAvailable, number: 13.1, unit: "g/dL", encounter: cardiology)
        try add("Allergy list", "Allergy: penicillin. Reaction: rash.", -28, kind: .allergy, label: "Penicillin", encounter: pcp)
        state.questions.append(Question(text: "My PCP list and cardiology instructions show different metoprolol doses. Can we clarify and update both records?", entityID: state.entities.first { $0.kind == .medication }?.id, sourceID: state.sources.first { $0.synthetic }?.id))
        state.profile.demoLoaded = true
    }
}
