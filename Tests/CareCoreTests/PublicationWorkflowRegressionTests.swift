import Foundation
import Testing
@testable import CareCore

struct FHIRMedicationIntentPublicationTests {
    private func medication(intent: String?, status: String = "active", verifiedPatient: Bool = true) throws -> FHIRImport {
        var resource: [String: Any] = ["resourceType": "MedicationRequest", "id": "fictional-request", "status": status,
            "subject": ["reference": "Patient/fictional"], "medicationCodeableConcept": ["text": "Fictional example medication"],
            "dosageInstruction": [["text": "Original fictional instructions", "doseAndRate": [["doseQuantity": ["value": 5, "unit": "mg"]]]]]]
        if let intent { resource["intent"] = intent }
        var entries = [["resource": resource]]
        if verifiedPatient { entries.insert(["resource": ["resourceType": "Patient", "id": "fictional"]], at: 0) }
        let bytes = try JSONSerialization.data(withJSONObject: ["resourceType": "Bundle", "entry": entries])
        return try FHIRImporter.parse(bytes, sourceID: UUID())
    }
    @Test(arguments: ["plan", "proposal", "option"])
    func activePlansNeverBecomeMedicationOrders(intent: String) throws {
        let result = try medication(intent: intent)
        let claim = try #require(result.claims.first)
        #expect(claim.action == .mentioned); #expect(claim.conditional)
        #expect(claim.certainty == .conditional); #expect(claim.subject == .patient)
        #expect(claim.review == .pending && !claim.canonical)
        #expect(claim.quote.contains("intent: " + intent) && result.text.contains(claim.quote))
        #expect(claim.value.contains("Original fictional instructions")); #expect(claim.numericValue == 5)
        #expect(claim.clarification != nil && claim.needsStrongReview)
    }
    @Test(arguments: ["order", "original-order", "reflex-order", "filler-order", "instance-order"])
    func explicitActiveOrdersRemainOrdered(intent: String) throws {
        let claim = try #require(medication(intent: intent).claims.first)
        #expect(claim.action == .ordered && !claim.conditional && claim.certainty == .documented)
        #expect(claim.review == .pending && !claim.canonical)
        #expect(claim.quote.contains("intent: " + intent))
    }
    @Test func missingOrUnknownIntentNeverInfersPrescriptionOrCessation() throws {
        for intent in [nil, "unknown", "unsupported"] as [String?] {
            for status in ["active", "stopped", "cancelled"] {
                let claim = try #require(medication(intent: intent, status: status).claims.first)
                #expect(claim.action == .mentioned); #expect(claim.confidence == 0.5)
                #expect(claim.certainty == .uncertain && claim.needsStrongReview)
                #expect(claim.quote.contains("intent: " + (intent ?? "not provided")))
                #expect(claim.clarification != nil)
            }
        }
    }
    @Test func cancelledPlanDoesNotSuggestStoppingAnOrderedMedicine() throws {
        let claim = try #require(medication(intent: "plan", status: "cancelled").claims.first)
        #expect(claim.action == .mentioned && claim.conditional)
    }
    @Test func unverifiedSubjectStillRequiresReviewAfterIntentIsRecognized() throws {
        let claim = try #require(medication(intent: "order", verifiedPatient: false).claims.first)
        #expect(claim.subject == .unknown && claim.needsStrongReview && !claim.canonical)
    }
}

struct AppointmentCalendarPublicationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func example() throws -> (CareState, Claim) {
        let source = Source(title: "Fictional calendar evidence", kind: .typed, text: "Fictional visit is scheduled.", contentHash: "fictional")
        var claim = Claim(sourceID: source.id, kind: .appointment, label: "Fictional visit", quote: source.workingText)
        claim.action = .scheduled; claim.certainty = .documented
        claim.dueAt = now.addingTimeInterval(7 * 86400); claim.duePrecision = .exact; claim.dueTimeKnown = true
        var state = CareState(); state.sources = [source]
        try Reconciler.accept([claim], into: &state, now: now)
        return (state, try #require(state.claims.first))
    }
    @Test func onlyExplicitReviewedCurrentAppointmentsCanExport() throws {
        let (state, claim) = try example()
        #expect(AppointmentCalendarPolicy.canExport(claim, in: state, now: now))
        for action in [ClaimAction.mentioned, .planned, .completed, .visitCompleted, .dismissed, .stopped, .requested] {
            var copy = state; copy.claims[0].action = action
            #expect(!AppointmentCalendarPolicy.canExport(copy.claims[0], in: copy, now: now))
        }
        for certainty in Certainty.allCases where ![.documented, .reported].contains(certainty) {
            var copy = state; copy.claims[0].certainty = certainty
            #expect(!AppointmentCalendarPolicy.canExport(copy.claims[0], in: copy, now: now))
        }
    }
    @Test func negatedConditionalUnreviewedUndatedPastAndOtherPatientClaimsCannotExport() throws {
        let (state, _) = try example()
        var variants: [Claim] = []
        var c = state.claims[0]; c.negated = true; variants.append(c)
        c = state.claims[0]; c.conditional = true; variants.append(c)
        c = state.claims[0]; c.review = .pending; variants.append(c)
        c = state.claims[0]; c.subject = .family; variants.append(c)
        c = state.claims[0]; c.dueAt = nil; variants.append(c)
        c = state.claims[0]; c.duePrecision = .approximate; variants.append(c)
        c = state.claims[0]; c.dueAt = now.addingTimeInterval(-2 * 86400); variants.append(c)
        for claim in variants {
            var copy = state; copy.claims[0] = claim
            #expect(!AppointmentCalendarPolicy.canExport(claim, in: copy, now: now))
        }
    }
    @Test func explicitSupersessionUnresolvedConflictsAndStaleCopiesAreBlocked() throws {
        var (state, first) = try example()
        var replacement = first; replacement.id = UUID(); replacement.userEdited = true
        replacement.supersedesID = first.id; replacement.dueAt = first.dueAt!.addingTimeInterval(86400)
        try Reconciler.accept([replacement], into: &state, now: now)
        #expect(!AppointmentCalendarPolicy.canExport(first, in: state, now: now))
        let active = try #require(state.claims.first { $0.id == replacement.id })
        #expect(AppointmentCalendarPolicy.canExport(active, in: state, now: now))
        var stale = active; stale.dueAt = active.dueAt!.addingTimeInterval(3600)
        #expect(!AppointmentCalendarPolicy.canExport(stale, in: state, now: now))
        var conflict = active; conflict.id = UUID(); conflict.supersedesID = nil; conflict.dueAt = active.dueAt!.addingTimeInterval(86400)
        try Reconciler.accept([conflict], into: &state, now: now)
        #expect(state.conflicts.contains { $0.status == .unresolved && $0.claimIDs.contains(active.id) })
        #expect(!AppointmentCalendarPolicy.canExport(active, in: state, now: now))
    }
    @Test func receiptContainsNoLabelDateOrPatientNameAndIsStableForSameEvent() throws {
        let (_, claim) = try example()
        let receipt = AppointmentCalendarPolicy.receiptKey(claim)
        #expect(receipt.count == 64 && !receipt.contains("Fictional"))
        var renamed = claim; renamed.label = "Different fictional title"; renamed.revision += 1
        #expect(AppointmentCalendarPolicy.receiptKey(renamed) == receipt)
        renamed.dueAt = claim.dueAt!.addingTimeInterval(3600)
        #expect(AppointmentCalendarPolicy.receiptKey(renamed) != receipt)
        #expect(AppointmentCalendarPolicy.claimKey(renamed) == AppointmentCalendarPolicy.claimKey(claim))
    }
}
