import Foundation
import Testing
@testable import CareCore

struct VisitCompanionTests {
    private let now = Date(timeIntervalSince1970: 1_710_000_000)
    private func session(_ state: CareState, _ id: UUID) throws -> VisitCompanion { try #require(state.visitCompanions?.sessions.first { $0.id == id }) }
    private func addSource(_ text: String, to state: inout CareState, synthetic: Bool = false) -> UUID {
        var source = Source(title: "Visit evidence", kind: .typed, text: text, contentHash: ContentHasher.hash(text))
        source.synthetic = synthetic; state.sources.append(source); return source.id
    }
    @Test func freshPatientCanStartWithOneThoughtAndUnknownVisitDate() throws {
        var state = CareState()
        let id = try VisitCompanionEngine.create(opening: "I want to understand what happens next.", in: &state, now: now)
        let value = try session(state, id)
        #expect(value.opening == "I want to understand what happens next.")
        #expect(value.questions.count == 3)
        #expect(value.eventAt == nil && value.encounterID == nil)
        #expect(state.claims.isEmpty && state.sources.isEmpty)
        #expect(VisitCompanionEngine.openingBrief(value).contains(value.opening))
    }
    @Test func copiedQuestionsAreSeparateEditableSnapshotsWithSources() throws {
        var state = CareState(); let sourceID = addSource("Original information", to: &state)
        let original = Question(text: "Can you explain my next step?", sourceID: sourceID)
        state.questions.append(original)
        let id = try VisitCompanionEngine.create(in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        #expect(question.originalQuestionID == original.id && question.sourceIDs == [sourceID] && question.copiedSnapshot)
        try VisitCompanionEngine.editQuestion(question.id, text: "Who should I contact?", answer: "I heard to contact the office.", progress: .discussed, companionID: id, in: &state, now: now)
        #expect(state.questions.first == original)
        #expect(try session(state, id).questions.first?.editedSnapshot == true)
        state.questions.removeAll()
        try VisitCompanionEngine.validate(state) // An independently deleted question does not break its deliberate visit snapshot.
    }
    @Test func orderedAgendaAndDraftsSurviveCodableRoundTrip() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let ids = try session(state, id).questions.map(\.id)
        try VisitCompanionEngine.reorder(ids.reversed(), companionID: id, in: &state, now: now)
        try VisitCompanionEngine.setPosition(ids[1], companionID: id, in: &state, now: now)
        try VisitCompanionEngine.saveAnswer("A partial answer to finish later.", questionID: ids[1], companionID: id, in: &state, now: now)
        try VisitCompanionEngine.markQuestion(.later, questionID: ids[1], companionID: id, in: &state, now: now)
        try VisitCompanionEngine.setProgress(.inVisit, companionID: id, in: &state, now: now)
        let restored = try JSONDecoder().decode(CareState.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        #expect(try session(restored, id).questions.map(\.id) == Array(ids.reversed()))
        #expect(try session(restored, id).currentQuestionID == ids[1])
        #expect(try session(restored, id).questions.first { $0.id == ids[1] }?.progress == .later)
        try VisitCompanionEngine.validate(restored)
    }
    @Test func captureIncludesOnlyPatientAnswersAndNeverAutoAcceptsClaims() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(opening: "PRIVATE_OPENING_NOT_FOR_EXTRACTION", in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.editQuestion(question.id, text: "GENERATED_PROMPT_DO_NOT_EXTRACT", answer: "CBC ordered next week.", progress: .discussed, companionID: id, in: &state, now: now)
        let sourceID = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        let source = try #require(state.source(sourceID))
        #expect(source.kind == .typed && source.state == .pending && source.eventAt == nil)
        #expect(source.workingText == "CBC ordered next week.")
        #expect(source.originalText.contains("GENERATED_PROMPT_DO_NOT_EXTRACT"))
        #expect(!source.workingText.contains("GENERATED_PROMPT") && !source.originalText.contains("PRIVATE_OPENING"))
        #expect(state.claims.isEmpty && state.loops.isEmpty && state.conflicts.isEmpty)
        #expect(try session(state, id).progress == .finished)
        #expect(try session(state, id).questions.filter { $0.answer.isEmpty }.count == 2)
    }

    @Test func sourceLinkedPromptsAreNotDuplicatedInsideCapturedOriginalEvidence() throws {
        var state = CareState(); let originalID = addSource("Original source context", to: &state)
        state.questions.append(Question(text: "SENSITIVE_COPIED_PROMPT", sourceID: originalID))
        let id = try VisitCompanionEngine.create(in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("My independent recollection.", questionID: question.id, companionID: id, in: &state, now: now)
        let capturedID = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        let original = try #require(state.source(capturedID)).originalText
        #expect(original.contains(question.id.uuidString) && original.contains("My independent recollection."))
        #expect(!original.contains("SENSITIVE_COPIED_PROMPT"))
        VisitCompanionEngine.removeSource(originalID, from: &state); state.sources.removeAll { $0.id == originalID }; state.questions.removeAll()
        #expect(state.source(capturedID)?.originalText == original)
        #expect(try session(state, id).questions.isEmpty)
        try VisitCompanionEngine.validate(state)
    }
    @Test func repeatCaptureIsIdempotentEvenAfterQuestionReorder() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let questions = try session(state, id).questions
        try VisitCompanionEngine.saveAnswer("First answer", questionID: questions[0].id, companionID: id, in: &state, now: now)
        try VisitCompanionEngine.saveAnswer("Second answer", questionID: questions[1].id, companionID: id, in: &state, now: now)
        let first = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        try VisitCompanionEngine.reorder(questions.map(\.id).reversed(), companionID: id, in: &state, now: now)
        let repeated = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now.addingTimeInterval(30))
        #expect(first == repeated && state.sources.count == 1)
        try VisitCompanionEngine.setProgress(.inVisit, companionID: id, in: &state, now: now)
        #expect(try session(state, id).answerCount == 2)
    }
    @Test func editedEvidenceCannotBeMistakenForUnchangedCapturedAnswers() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("My original recollection.", questionID: question.id, companionID: id, in: &state, now: now)
        let first = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        let sourceIndex = try #require(state.sources.firstIndex { $0.id == first })
        state.sources[sourceIndex].workingText = "Edited elsewhere."
        let second = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        #expect(first != second && state.sources.count == 2)
        #expect(state.source(second)?.workingText == "My original recollection.")
    }
    @Test func deletingSourceScrubsCopiedQuestionsAndTheirDrafts() throws {
        var state = CareState(); let sourceID = addSource("SENSITIVE_SOURCE", to: &state)
        state.questions.append(Question(text: "SENSITIVE_COPIED_QUESTION", sourceID: sourceID))
        let id = try VisitCompanionEngine.create(in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("SENSITIVE_LINKED_DRAFT", questionID: question.id, companionID: id, in: &state, now: now)
        VisitCompanionEngine.removeSource(sourceID, from: &state); state.sources.removeAll { $0.id == sourceID }; state.questions.removeAll()
        let value = try session(state, id)
        #expect(value.questions.isEmpty && value.currentQuestionID == nil && value.removedQuestionCount == 1)
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        #expect(!encoded.contains("SENSITIVE"))
        try VisitCompanionEngine.validate(state)
    }
    @Test func deletingCapturedAnswerEvidenceClearsRemainingCachedDrafts() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("SENSITIVE_CAPTURED_ANSWER", questionID: question.id, companionID: id, in: &state, now: now)
        let sourceID = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        VisitCompanionEngine.removeSource(sourceID, from: &state); state.sources.removeAll { $0.id == sourceID }
        let value = try session(state, id)
        #expect(value.answerCount == 0 && value.clearedAnswerCount == 1)
        #expect(value.lastCaptureSourceID == nil && value.lastCaptureDigest == nil && value.capturedSourceIDs.isEmpty)
        #expect(throws: CareError.self) { try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now) }
        #expect(!String(decoding: try JSONEncoder().encode(value), as: UTF8.self).contains("SENSITIVE_CAPTURED_ANSWER"))
    }
    @Test func removingCompanionKeepsCapturedSourceAndGlobalQuestions() throws {
        var state = CareState(); state.questions.append(Question(text: "Keep original question"))
        let id = try VisitCompanionEngine.create(in: &state, now: now), question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("Keep my captured recollection.", questionID: question.id, companionID: id, in: &state, now: now)
        let sourceID = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        VisitCompanionEngine.remove(id, from: &state)
        #expect(state.source(sourceID) != nil && state.questions.count == 1)
        #expect(state.visitCompanions?.sessions.isEmpty == true)
    }
    @Test func syntheticFlagCanBeExplicitlyOffButCopiedDemoContextStaysLabeled() throws {
        var state = CareState(); state.profile.demoLoaded = true
        let real = try VisitCompanionEngine.create(synthetic: false, in: &state, now: now)
        #expect(try session(state, real).includesSynthetic == false)
        let sourceID = addSource("Fictional source", to: &state, synthetic: true)
        state.questions.append(Question(text: "Question about fictional source", sourceID: sourceID))
        let demo = try VisitCompanionEngine.create(synthetic: false, in: &state, now: now)
        #expect(try session(state, demo).includesSynthetic == false)
        #expect(try session(state, demo).questions.allSatisfy { !$0.synthetic })
        let suggestion = try #require(VisitCompanionEngine.suggestions(state).first { $0.sourceIDs.contains(sourceID) })
        try VisitCompanionEngine.addSuggestion(suggestion.id, companionID: demo, in: &state, now: now)
        #expect(try session(state, demo).includesSynthetic)
        #expect(VisitCompanionEngine.openingBrief(try session(state, demo)).contains("SYNTHETIC DEMO"))
    }

    @Test func unansweredSyntheticContextDoesNotLabelRealAnswersSynthetic() throws {
        var state = CareState(); state.profile.demoLoaded = true
        let sourceID = addSource("Fictional source", to: &state, synthetic: true)
        state.questions.append(Question(text: "A fictional question", sourceID: sourceID))
        let id = try VisitCompanionEngine.create(synthetic: false, in: &state, now: now)
        let first = try #require(session(state, id).questions.first)
        let suggestion = try #require(VisitCompanionEngine.suggestions(state).first)
        try VisitCompanionEngine.addSuggestion(suggestion.id, companionID: id, in: &state, now: now)
        try VisitCompanionEngine.saveAnswer("My real visit recollection.", questionID: first.id, companionID: id, in: &state, now: now)
        let realSource = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        #expect(state.source(realSource)?.synthetic == false)
        #expect(try session(state, id).includesSynthetic) // The on-screen agenda still labels the copied demo context.
        let demoQuestion = try #require(session(state, id).questions.first { $0.synthetic })
        try VisitCompanionEngine.saveAnswer("A fictional answer.", questionID: demoQuestion.id, companionID: id, in: &state, now: now)
        let before = state
        #expect(throws: CareError.self) { try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now) }
        #expect(state == before) // Mixed drafts must not turn real content into disposable demo evidence.
        #expect(state.source(realSource)?.synthetic == false)
        try VisitCompanionEngine.saveAnswer("", questionID: first.id, companionID: id, in: &state, now: now)
        let demoSource = try VisitCompanionEngine.captureAnswers(companionID: id, in: &state, now: now)
        #expect(state.source(demoSource)?.synthetic == true)
    }
    @Test func briefContainsOnlyTheChosenFirstThreeAndNotAnswersOrLaterQuestionText() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        try VisitCompanionEngine.addQuestion("PRIVATE_LATER_QUESTION", companionID: id, in: &state, now: now)
        let question = try #require(session(state, id).questions.first)
        try VisitCompanionEngine.saveAnswer("PRIVATE_ANSWER", questionID: question.id, companionID: id, in: &state, now: now)
        let text = VisitCompanionEngine.openingBrief(try session(state, id))
        #expect(!text.contains("PRIVATE_LATER_QUESTION") && !text.contains("PRIVATE_ANSWER"))
        #expect(text.contains("1 additional questions"))
    }
    @Test func invalidUpdatesAreAtomicAndLegacyStateDecodes() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let before = state
        #expect(throws: CareError.self) { try VisitCompanionEngine.edit(id, title: "", opening: "", eventAt: nil, in: &state, now: now) }
        #expect(state == before)
        #expect(throws: CareError.self) { try VisitCompanionEngine.reorder([UUID()], companionID: id, in: &state, now: now) }
        #expect(state == before)
        #expect(throws: CareError.self) { try VisitCompanionEngine.addQuestion(String(repeating: "x", count: 2001), companionID: id, in: &state, now: now) }
        #expect(state == before)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]); object.removeValue(forKey: "visitCompanions")
        let legacy = try JSONDecoder().decode(CareState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.visitCompanions == nil)
    }
    @Test func encounterDateIsExplicitAndDetachmentKeepsVisitNotes() throws {
        var state = CareState(); let encounter = EncounterRecord(title: "Office visit", date: now); state.encounters.append(encounter)
        let id = try VisitCompanionEngine.create(encounterID: encounter.id, in: &state, now: now)
        #expect(try session(state, id).eventAt == now)
        VisitCompanionEngine.detachEncounter(encounter.id, from: &state); state.encounters.removeAll()
        #expect(try session(state, id).encounterID == nil)
        #expect(try session(state, id).eventAt == now)
        try VisitCompanionEngine.validate(state)
    }

    @Test func upcomingAppointmentDateIsSeparateFromReportingEncounter() throws {
        var state = CareState(); let oldEncounter = EncounterRecord(title: "Earlier appointment", date: now.addingTimeInterval(-86_400 * 30)); state.encounters.append(oldEncounter)
        let upcoming = now.addingTimeInterval(86_400 * 7)
        let id = try VisitCompanionEngine.create(title: "Upcoming appointment", eventAt: upcoming, in: &state, now: now)
        #expect(try session(state, id).eventAt == upcoming)
        #expect(try session(state, id).encounterID == nil)
        let explicit = try VisitCompanionEngine.create(encounterID: oldEncounter.id, eventAt: upcoming, in: &state, now: now)
        #expect(try session(state, explicit).eventAt == upcoming)
        #expect(try session(state, explicit).encounterID == oldEncounter.id)
    }
    @Test func archiveValidationRejectsDuplicateQuestionIDsAndDanglingSourceLinks() throws {
        var state = CareState(); let id = try VisitCompanionEngine.create(in: &state, now: now)
        let first = try #require(session(state, id).questions.first)
        state.visitCompanions!.sessions[0].questions.append(first)
        #expect(throws: CareError.self) { try VisitCompanionEngine.validate(state) }
        state.visitCompanions!.sessions[0].questions.removeLast()
        state.visitCompanions!.sessions[0].questions[0].sourceIDs = [UUID()]
        #expect(throws: CareError.self) { try VisitCompanionEngine.validate(state) }
    }
}
