import Foundation
import Testing
@testable import CareCore

struct WorkflowHardeningTests {
    @Test func largeIntervalsDoNotOverflowOrInventDates() throws {
        let text = "Follow up in 9223372036854775807 weeks"
        let source = Source(title: "Synthetic", kind: .typed, text: text, contentHash: ContentHasher.hash(Data(text.utf8)), eventAt: Date())
        let claims = try LocalExtractor.proposals(source)
        #expect(!claims.isEmpty); #expect(claims.allSatisfy { $0.intervalDays == nil && $0.dueAt == nil })
    }
    @Test func askDoesNotReturnUnrelatedClaimsFromMatchingSource() async throws {
        let text = "Medication: metoprolol 25 mg daily\nAllergy: penicillin"
        let source = Source(title: "Synthetic", kind: .typed, text: text, contentHash: ContentHasher.hash(Data(text.utf8)))
        var state = CareState(); state.sources = [source]
        try Reconciler.accept(LocalExtractor.proposals(source), into: &state)
        let answer = try await LocalGroundedSynthesis().answer("What is saved about metoprolol?", state: state)
        #expect(!answer.isEmpty); #expect(answer.allSatisfy { !$0.summary.lowercased().contains("penicillin") })
        #expect(try await LocalGroundedSynthesis().answer("show me my saved care", state: state).isEmpty)
    }
    @Test func searchIncludesReviewedValuesBeyondRawSourceText() throws {
        let source = Source(title: "Synthetic note", kind: .typed, text: "The medication name needs review.", contentHash: "test")
        var claim = Claim(sourceID: source.id, kind: .medication, label: "Metoprolol", quote: source.workingText)
        claim.value = "patient corrected spelling"; claim.userEdited = true
        var state = CareState(); state.sources = [source]; try Reconciler.accept([claim], into: &state)
        #expect(SearchEngine.search("corrected", state: state).contains { $0.type == "Reviewed claim" })
        #expect(SearchEngine.search("top", state: state).isEmpty)
    }
}

struct ClaimIdentityRegressionTests {
    private func example() -> (CareState, Claim) {
        let source = Source(title: "Synthetic timing", kind: .typed, text: "Follow-up requested; timing clarified.", contentHash: "timing")
        var state = CareState(); state.sources = [source]
        var claim = Claim(sourceID: source.id, kind: .followUp, label: "Follow-up", quote: source.workingText)
        claim.action = .requested; claim.eventAt = Date(timeIntervalSince1970: 1_000_000)
        return (state, claim)
    }
    @Test func differingIntervalsAreNotDiscardedAsDuplicates() throws {
        var (state, first) = example(); first.intervalDays = 7
        var second = first; second.id = UUID(); second.intervalDays = 14
        try Reconciler.accept([first, second], into: &state)
        #expect(state.claims.filter(\.canonical).count == 2)
        #expect(state.conflicts.contains { $0.reason.contains("interval") })
    }
    @Test func identityPreservesEffectiveDatePrecisionCodesAndAttribution() {
        let (_, original) = example()
        var variants: [Claim] = []
        var c = original; c.effectiveAt = Date(); variants.append(c)
        c = original; c.duePrecision = .approximate; variants.append(c)
        c = original; c.dueTimeKnown = true; variants.append(c)
        c = original; c.codeSystem = "test"; c.code = "code"; variants.append(c)
        c = original; c.provenance = .documentDerived; variants.append(c)
        c = original; c.speaker = "clinician"; variants.append(c)
        c = original; c.relatedEntityID = UUID(); c.relation = .followUpFor; variants.append(c)
        c = original; c.supersedesID = UUID(); variants.append(c)
        #expect(variants.allSatisfy { !Normalizer.equivalent(original, $0) })
    }
    @Test func duplicateRelationshipSurvivesRebuild() throws {
        var (state, first) = example()
        var second = first; second.id = UUID()
        try Reconciler.accept([first, second], into: &state)
        #expect(state.claims.filter(\.canonical).count == 1)
        #expect(state.relations.contains { $0.kind == .duplicateOf && $0.from == second.id && $0.to == first.id })
        Reconciler.rebuild(&state)
        #expect(state.relations.contains { $0.kind == .duplicateOf && $0.from == second.id })
    }
    @Test func sourceRetirementStillAllowsBackup() throws {
        var (state, claim) = example()
        try Reconciler.accept([claim], into: &state)
        state.sources[0].previousText.append(state.sources[0].workingText)
        state.sources[0].workingText = "Corrected working text"
        state.claims[0].review = .rejected
        Reconciler.rebuild(&state)
        #expect(state.entities.isEmpty)
        try CareArchive(state: state, files: [:]).validate()
    }
}

struct AssociationHistoryRegressionTests {
    @Test func sameNameWithDifferentKnownCodeRequiresReview() {
        var entity = Entity(kind: .medication, label: "Synthetic medication")
        entity.codeSystem = "http://www.nlm.nih.gov/research/umls/rxnorm"; entity.code = "111"
        var claim = Claim(sourceID: UUID(), kind: .medication, label: entity.label, quote: "Synthetic medication")
        claim.codeSystem = entity.codeSystem; claim.code = "222"
        let candidates = EntityResolver.candidates(for: claim, in: [entity])
        #expect(candidates.count == 1)
        #expect(candidates.allSatisfy { !$0.automatic })
    }
    @Test func retiringOnlyClaimKeepsPersonalContextAccessible() throws {
        let source = Source(title: "Synthetic", kind: .typed, text: "Condition: asthma", contentHash: "source")
        var state = CareState(); state.sources = [source]
        let claim = Claim(sourceID: source.id, kind: .condition, label: "Asthma", quote: source.workingText)
        try Reconciler.accept([claim], into: &state)
        let entity = try #require(state.entities.first)
        state.notes = [Note(text: "Remember my question", entityID: entity.id)]
        state.questions = [Question(text: "What changed?", entityID: entity.id)]
        state.claims[0].review = .rejected
        Reconciler.rebuild(&state)
        #expect(state.notes.count == 1 && state.notes[0].entityID == nil)
        #expect(state.questions.count == 1 && state.questions[0].entityID == nil)
        let archive = CareArchive(state: state, files: [:])
        let bytes = try ArchiveCodec.encrypt(archive, passphrase: "a patient-owned backup phrase")
        let restored = try ArchiveCodec.decrypt(bytes, passphrase: "a patient-owned backup phrase")
        #expect(restored.state.claims.count == 1)
        #expect(restored.state.claims[0].review == .rejected)
    }
}

struct AppointmentPrecisionRegressionTests {
    @Test func unknownTimeDoesNotDisagreeWithTimeOnSameDay() throws {
        let day = try #require(DateParser.parse("2026-10-01"))
        let entity = UUID()
        var dateOnly = Claim(sourceID: UUID(), kind: .appointment, label: "Visit", quote: "Visit on October 1")
        dateOnly.entityID = entity; dateOnly.dueAt = day; dateOnly.duePrecision = .exact
        var timed = dateOnly; timed.id = UUID(); timed.dueTimeKnown = true
        timed.dueAt = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: day)
        #expect(Reconciler.conflictReason(dateOnly, timed) == nil)
        timed.dueAt = Calendar.current.date(byAdding: .day, value: 1, to: day)
        #expect(Reconciler.conflictReason(dateOnly, timed) != nil)
    }
    @Test func eventDateDoesNotSubstituteForMissingAppointmentDate() {
        let entity = UUID()
        var a = Claim(sourceID: UUID(), kind: .appointment, label: "Visit", quote: "An appointment was discussed")
        a.entityID = entity; a.eventAt = Date(timeIntervalSince1970: 100)
        var b = a; b.id = UUID(); b.dueAt = Date(timeIntervalSince1970: 10_000)
        #expect(Reconciler.conflictReason(a, b) == nil)
    }
    @Test func followUpDatesOneDayApartAreCompared() throws {
        var a = Claim(sourceID: UUID(), kind: .followUp, label: "Follow-up", quote: "Follow-up requested")
        a.entityID = UUID(); a.dueAt = try #require(DateParser.parse("2026-10-01")); a.duePrecision = .exact
        var b = a; b.id = UUID(); b.dueAt = Calendar.current.date(byAdding: .day, value: 1, to: a.dueAt!)
        #expect(Reconciler.conflictReason(a, b) != nil)
    }
}

struct ReminderTimingRegressionTests {
    @Test func appointmentReminderNeverFiresAfterAppointment() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = CareState(); state.profile.notifications = true; state.profile.notifyAppointments = true
        var claim = Claim(sourceID: UUID(), kind: .appointment, label: "Synthetic visit", quote: "Visit")
        claim.review = .accepted; claim.entityID = UUID(); claim.action = .scheduled; claim.duePrecision = .exact
        claim.dueTimeKnown = true; claim.dueAt = now.addingTimeInterval(30)
        state.claims = [claim]
        #expect(state.upcomingAppointments(now: now).count == 1)
        #expect(ReminderPlanner.plan(state, now: now).isEmpty)
        state.claims[0].dueAt = now.addingTimeInterval(120)
        let reminders = ReminderPlanner.plan(state, now: now)
        #expect(reminders.count == 1)
        #expect(reminders.allSatisfy { $0.date > now && $0.date < state.claims[0].dueAt! })
    }
}

struct FHIRDetailRegressionTests {
    @Test func mixedPatientReferencesWithoutPatientResourcesAreRejected() throws {
        let json = #"{"resourceType":"Bundle","entry":[{"resource":{"resourceType":"Observation","subject":{"reference":"Patient/a"},"code":{"text":"Test"}}},{"resource":{"resourceType":"Observation","subject":{"reference":"Patient/b"},"code":{"text":"Test"}}}]}"#
        #expect(throws: (any Error).self) { try FHIRImporter.parse(Data(json.utf8), sourceID: UUID()) }
    }
    @Test func medicationInstructionsAndReactionDetailsArePreserved() throws {
        let json = #"{"resourceType":"Bundle","entry":[{"resource":{"resourceType":"MedicationRequest","status":"active","medicationCodeableConcept":{"text":"Example medication"},"dosageInstruction":[{"text":"Take as needed","asNeededBoolean":true,"route":{"text":"Oral"},"timing":{"code":{"text":"Once daily"}},"doseAndRate":[{"doseQuantity":{"value":5,"unit":"mg"}}]}]}},{"resource":{"resourceType":"AllergyIntolerance","code":{"text":"Latex"},"reaction":[{"manifestation":[{"text":"Rash"}],"severity":"mild"}]}}]}"#
        let result = try FHIRImporter.parse(Data(json.utf8), sourceID: UUID())
        let medication = try #require(result.claims.first)
        #expect(medication.route == "Oral")
        #expect(medication.frequency == "Once daily")
        #expect(medication.numericValue == 5)
        #expect(medication.conditional)
        #expect(medication.value.contains("Take as needed"))
        #expect(result.claims[1].value.contains("Rash"))
        #expect(result.claims[1].value.contains("mild"))
        #expect(result.claims.allSatisfy { result.text.contains($0.quote) && $0.review == .pending })
    }
    @Test func multipleDosesNeverFlattenToFirstDose() throws {
        let json = #"{"resourceType":"MedicationRequest","status":"active","medicationCodeableConcept":{"text":"Example"},"dosageInstruction":[{"text":"Morning instruction","doseAndRate":[{"doseQuantity":{"value":5,"unit":"mg"}}]},{"text":"Evening instruction","doseAndRate":[{"doseQuantity":{"value":10,"unit":"mg"}}]}]}"#
        let claim = try #require(FHIRImporter.parse(Data(json.utf8), sourceID: UUID()).claims.first)
        #expect(claim.numericValue == nil)
        #expect(claim.value.contains("Morning instruction"))
        #expect(claim.value.contains("Evening instruction"))
        #expect(claim.confidence == 0.5)
        #expect(claim.clarification != nil)
    }
}
