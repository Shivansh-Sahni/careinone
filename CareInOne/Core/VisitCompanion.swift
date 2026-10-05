import Foundation

public enum VisitCompanionProgress: String, Codable, CaseIterable, Sendable {
    case preparing, inVisit, finished
    public var title: String { switch self { case .preparing: "Getting ready"; case .inVisit: "In my visit"; case .finished: "Finished by you" } }
}
public enum VisitQuestionProgress: String, Codable, CaseIterable, Sendable {
    case ready, discussed, later
    public var title: String { switch self { case .ready: "Ready to ask"; case .discussed: "Discussed"; case .later: "Ask later" } }
}
public struct VisitCompanionQuestion: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var text: String
    public var answer = ""
    public var progress: VisitQuestionProgress = .ready
    /// A copied agenda item is a snapshot. Editing it never rewrites the original question or source.
    public var originalQuestionID: UUID?
    public var sourceIDs: [UUID] = []
    public var copiedSnapshot = false
    public var editedSnapshot = false
    public var synthetic = false
    public init(text: String) { self.text = text }
}
public struct VisitCompanion: Codable, Equatable, Sendable, Identifiable {
    public var id = UUID()
    public var title: String
    public var encounterID: UUID?
    public var eventAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var opening = ""
    public var questions: [VisitCompanionQuestion] = []
    public var currentQuestionID: UUID?
    public var progress: VisitCompanionProgress = .preparing
    public var capturedSourceIDs: [UUID] = []
    public var lastCaptureDigest: String?
    public var lastCaptureSourceID: UUID?
    public var synthetic = false
    public var removedQuestionCount = 0
    public var clearedAnswerCount = 0
    public var answerCount: Int { questions.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    public var includesSynthetic: Bool { synthetic || questions.contains(where: \.synthetic) }
    public init(title: String, createdAt: Date = Date()) { self.title = title; self.createdAt = createdAt; self.updatedAt = createdAt }
}
public struct VisitCompanionMemory: Codable, Equatable, Sendable {
    public var version = 1
    public var sessions: [VisitCompanion] = []
    public init() {}
}
public struct VisitCompanionSuggestion: Identifiable, Sendable {
    public var id: String
    public var text: String
    public var originalQuestionID: UUID?
    public var sourceIDs: [UUID]
    public var synthetic: Bool
    public var reason: String
}

/// Organizational help for a conversation. No generated prompt is a clinical instruction.
public enum VisitCompanionEngine {
    public static let maximumSessions = 50
    public static let maximumQuestions = 40
    public static let maximumTextCharacters = 500_000

    public static func suggestions(_ state: CareState, encounterID: UUID? = nil) -> [VisitCompanionSuggestion] {
        var result: [VisitCompanionSuggestion] = []
        func add(_ id: String, _ text: String, _ sources: [UUID], questionID: UUID? = nil, reason: String) {
            let ids = Array(Set(sources.filter { state.source($0) != nil })).sorted { $0.uuidString < $1.uuidString }
            guard !text.isEmpty, text.count <= 2000 else { return }
            result.append(VisitCompanionSuggestion(id: id, text: text, originalQuestionID: questionID, sourceIDs: ids, synthetic: ids.contains { state.source($0)?.synthetic == true }, reason: reason))
        }
        for question in state.questions.filter({ !$0.answered && (encounterID == nil || $0.encounterID == nil || $0.encounterID == encounterID) }).sorted(by: { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }) {
            add("question:" + question.id.uuidString, question.text, question.sourceID.map { [$0] } ?? [], questionID: question.id, reason: "Your saved question · copies into this visit")
        }
        let canonical = Dictionary(uniqueKeysWithValues: state.claims.filter(\.canonical).map { ($0.id, $0) })
        for conflict in state.conflicts.filter({ $0.status == .unresolved }).sorted(by: { $0.id < $1.id }) {
            add("conflict:" + conflict.id, conflict.question, conflict.claimIDs.compactMap { canonical[$0]?.sourceID }, reason: "Different saved reports to clarify")
        }
        for loop in state.loops.filter({ [.open, .uncertain].contains($0.status) }).sorted(by: { $0.id < $1.id }) {
            add("loop:" + loop.id, "Can we confirm the next step for \(loop.title), who arranges it, and when?", loop.claimIDs.compactMap { canonical[$0]?.sourceID }, reason: "An open step in your saved care")
        }
        return Array(result.prefix(100))
    }

    @discardableResult public static func create(title: String = "My next appointment", encounterID: UUID? = nil, eventAt: Date? = nil, opening: String = "", synthetic: Bool? = nil, in state: inout CareState, now: Date = Date()) throws -> UUID {
        var memory = state.visitCompanions ?? VisitCompanionMemory()
        guard memory.sessions.count < maximumSessions else { throw CareError.invalid("You can save up to 50 appointment companions. Remove an older one to make room.") }
        if let encounterID, !state.encounters.contains(where: { $0.id == encounterID }) { throw CareError.invalid("This encounter has been removed.") }
        var session = VisitCompanion(title: title.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: now)
        session.encounterID = encounterID; session.eventAt = eventAt ?? state.encounters.first { $0.id == encounterID }?.date
        session.opening = opening; session.synthetic = synthetic ?? state.profile.demoLoaded
        let saved = suggestions(state, encounterID: encounterID).filter { $0.originalQuestionID != nil && (session.synthetic || !$0.synthetic) }.prefix(3)
        session.questions = saved.map(question)
        if session.questions.isEmpty {
            session.questions = ["What is the most important thing for me to understand today?", "What happens next, and who will arrange it?", "Who should I contact if I need clarification?"].map { VisitCompanionQuestion(text: $0) }
        }
        session.currentQuestionID = session.questions.first?.id
        memory.sessions.append(session)
        var candidate = state; candidate.visitCompanions = memory; try validate(candidate)
        state.visitCompanions = memory; state.audit.append(Audit(action: "visit_companion_created"))
        return session.id
    }

    private static func question(_ suggestion: VisitCompanionSuggestion) -> VisitCompanionQuestion {
        var value = VisitCompanionQuestion(text: suggestion.text)
        value.originalQuestionID = suggestion.originalQuestionID; value.sourceIDs = suggestion.sourceIDs
        value.copiedSnapshot = true; value.synthetic = suggestion.synthetic
        return value
    }
    private static func update(_ id: UUID, in state: inout CareState, now: Date, change: (inout VisitCompanion) throws -> Void) throws {
        guard var memory = state.visitCompanions, let index = memory.sessions.firstIndex(where: { $0.id == id }) else { throw CareError.invalid("This appointment companion has been removed.") }
        try change(&memory.sessions[index]); memory.sessions[index].updatedAt = now
        var candidate = state; candidate.visitCompanions = memory; try validate(candidate)
        state.visitCompanions = memory
    }
    public static func edit(_ id: UUID, title: String, opening: String, eventAt: Date?, synthetic: Bool? = nil, in state: inout CareState, now: Date = Date()) throws {
        try update(id, in: &state, now: now) { $0.title = title.trimmingCharacters(in: .whitespacesAndNewlines); $0.opening = opening; $0.eventAt = eventAt; if let synthetic { $0.synthetic = synthetic } }
    }
    public static func addQuestion(_ text: String, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            let value = VisitCompanionQuestion(text: text.trimmingCharacters(in: .whitespacesAndNewlines))
            session.questions.append(value); if session.currentQuestionID == nil { session.currentQuestionID = value.id }
        }
    }
    public static func addSuggestion(_ suggestionID: String, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        guard let session = state.visitCompanions?.sessions.first(where: { $0.id == companionID }), let suggestion = suggestions(state, encounterID: session.encounterID).first(where: { $0.id == suggestionID }) else { throw CareError.invalid("This suggested question is no longer available.") }
        guard !session.questions.contains(where: { Normalizer.key($0.text) == Normalizer.key(suggestion.text) }) else { return }
        try update(companionID, in: &state, now: now) { session in
            let value = question(suggestion); session.questions.append(value)
            if session.currentQuestionID == nil { session.currentQuestionID = value.id }
        }
    }
    public static func editQuestion(_ questionID: UUID, text: String, answer: String, progress: VisitQuestionProgress, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            guard let i = session.questions.firstIndex(where: { $0.id == questionID }) else { throw CareError.invalid("This question has been removed.") }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if session.questions[i].copiedSnapshot && trimmed != session.questions[i].text { session.questions[i].editedSnapshot = true }
            session.questions[i].text = trimmed; session.questions[i].answer = answer; session.questions[i].progress = progress
        }
    }
    public static func saveAnswer(_ answer: String, questionID: UUID, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            guard let i = session.questions.firstIndex(where: { $0.id == questionID }) else { throw CareError.invalid("This question has been removed.") }
            session.questions[i].answer = answer
        }
    }
    public static func markQuestion(_ progress: VisitQuestionProgress, questionID: UUID, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            guard let i = session.questions.firstIndex(where: { $0.id == questionID }) else { throw CareError.invalid("This question has been removed.") }
            session.questions[i].progress = progress
        }
    }
    public static func reorder(_ ids: [UUID], companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            guard ids.count == session.questions.count, Set(ids) == Set(session.questions.map(\.id)) else { throw CareError.invalid("The question list changed. Try moving it again.") }
            let lookup = Dictionary(uniqueKeysWithValues: session.questions.map { ($0.id, $0) }); session.questions = ids.compactMap { lookup[$0] }
        }
    }
    public static func removeQuestion(_ questionID: UUID, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { session in
            session.questions.removeAll { $0.id == questionID }
            if session.currentQuestionID == questionID { session.currentQuestionID = session.questions.first?.id }
        }
    }
    public static func setPosition(_ questionID: UUID?, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { $0.currentQuestionID = questionID }
    }
    public static func setProgress(_ progress: VisitCompanionProgress, companionID: UUID, in state: inout CareState, now: Date = Date()) throws {
        try update(companionID, in: &state, now: now) { $0.progress = progress }
    }
    public static func openingBrief(_ session: VisitCompanion) -> String {
        var lines = ["MY APPOINTMENT · \(session.title)"]
        if session.includesSynthetic { lines.append("SYNTHETIC DEMO — not a real patient's record.") }
        if let eventAt = session.eventAt { lines.append("Visit date: \(eventAt.formatted(date: .abbreviated, time: .omitted))") }
        if !session.opening.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines += ["", "What matters to me today:", session.opening] }
        if !session.questions.isEmpty {
            lines += ["", "The three questions I want to start with:"]
            for (i, item) in session.questions.prefix(3).enumerated() { lines.append("\(i + 1). \(item.text)") }
            if session.questions.count > 3 { lines.append("I also have \(session.questions.count - 3) additional questions saved separately if we have time.") }
        }
        lines += ["", "Patient-prepared conversation agenda. Questions and recollections are not verified clinical instructions."]
        return lines.joined(separator: "\n")
    }

    /// Repeated capture of the same answer set and event date returns the same preserved source.
    /// Only patient-entered answers become working text; copied prompts never enter extraction.
    @discardableResult public static func captureAnswers(companionID: UUID, in state: inout CareState, now: Date = Date()) throws -> UUID {
        guard var session = state.visitCompanions?.sessions.first(where: { $0.id == companionID }) else { throw CareError.invalid("This appointment companion has been removed.") }
        let answered = session.questions.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !answered.isEmpty else { throw CareError.invalid("Write at least one answer or recollection before saving visit evidence.") }
        guard session.synthetic || !answered.contains(where: \.synthetic) || answered.allSatisfy(\.synthetic) else {
            throw CareError.invalid("These answers mix your own visit with synthetic practice. Keep them in separate companions: clear the synthetic answer here before saving your real visit evidence. Your drafts are still saved.")
        }
        let capturedSynthetic = session.synthetic || answered.contains(where: \.synthetic)
        let working = answered.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.answer).joined(separator: "\n\n")
        let dateKey = session.eventAt.map { String($0.timeIntervalSinceReferenceDate) } ?? "unknown"
        // Sort by ID so reordering the agenda does not duplicate unchanged evidence.
        let identity = answered.sorted { $0.id.uuidString < $1.id.uuidString }.map { $0.id.uuidString + ":" + ContentHasher.hash($0.answer) }.joined(separator: "|")
        let digest = ContentHasher.hash(identity + "|" + dateKey + "|" + String(capturedSynthetic))
        let contextualAnswers = answered.sorted { $0.id.uuidString < $1.id.uuidString }.map { question in
            let prompt = question.sourceIDs.isEmpty
                ? "Agenda question (a prompt, not a clinical instruction):\n" + question.text
                : "Answer to source-linked agenda question " + question.id.uuidString + ". Its wording remains with the supporting source."
            return prompt + "\nMy reported answer:\n" + question.answer
        }.joined(separator: "\n\n")
        let content = "My appointment recollection — patient reported, not clinician verified. Agenda prompts provide context only; analysis uses my answer text.\n\n" + contextualAnswers
        if session.lastCaptureDigest == digest, let id = session.lastCaptureSourceID, let existing = state.source(id),
           existing.originalText == content, existing.workingText == working, existing.contentHash == ContentHasher.hash(content),
           existing.eventAt == session.eventAt, existing.synthetic == capturedSynthetic {
            try setProgress(.finished, companionID: companionID, in: &state, now: now); return id
        }
        try validate(state)
        var source = Source(title: "My answers · " + String(session.title.prefix(160)), kind: .typed, text: content, contentHash: ContentHasher.hash(content), eventAt: session.eventAt)
        source.workingText = working; source.capturedAt = now; source.encounterID = session.encounterID
        source.synthetic = capturedSynthetic; source.state = .pending
        source.processingMessage = "Your answers are saved. Review extracted information before it updates My Care."
        session.capturedSourceIDs.append(source.id); session.lastCaptureDigest = digest; session.lastCaptureSourceID = source.id
        session.progress = .finished; session.updatedAt = now
        var candidate = state; candidate.sources.append(source)
        let i = candidate.visitCompanions!.sessions.firstIndex { $0.id == companionID }!
        candidate.visitCompanions!.sessions[i] = session; try validate(candidate)
        state = candidate; state.audit.append(Audit(action: "visit_answers_captured", count: answered.count))
        return source.id
    }
    public static func remove(_ id: UUID, from state: inout CareState) {
        state.visitCompanions?.sessions.removeAll { $0.id == id }; state.audit.append(Audit(action: "visit_companion_removed"))
    }
    public static func removeSource(_ id: UUID, from state: inout CareState) {
        guard var memory = state.visitCompanions else { return }
        for i in memory.sessions.indices {
            let removed = memory.sessions[i].questions.filter { $0.sourceIDs.contains(id) }
            memory.sessions[i].questions.removeAll { $0.sourceIDs.contains(id) }
            memory.sessions[i].removedQuestionCount += removed.count
            if !memory.sessions[i].questions.contains(where: { $0.id == memory.sessions[i].currentQuestionID }) { memory.sessions[i].currentQuestionID = memory.sessions[i].questions.first?.id }
            if memory.sessions[i].capturedSourceIDs.contains(id) {
                memory.sessions[i].clearedAnswerCount += memory.sessions[i].questions.filter { !$0.answer.isEmpty }.count
                for j in memory.sessions[i].questions.indices { memory.sessions[i].questions[j].answer = "" }
            }
            memory.sessions[i].capturedSourceIDs.removeAll { $0 == id }
            if memory.sessions[i].lastCaptureSourceID == id { memory.sessions[i].lastCaptureSourceID = nil; memory.sessions[i].lastCaptureDigest = nil }
        }
        state.visitCompanions = memory
    }
    public static func detachEncounter(_ id: UUID, from state: inout CareState) {
        guard var memory = state.visitCompanions else { return }
        for i in memory.sessions.indices where memory.sessions[i].encounterID == id { memory.sessions[i].encounterID = nil }
        state.visitCompanions = memory
    }
    public static func validate(_ state: CareState) throws {
        guard let memory = state.visitCompanions else { return }
        guard memory.version == 1, memory.sessions.count <= maximumSessions, Set(memory.sessions.map(\.id)).count == memory.sessions.count else { throw CareError.invalid("The appointment companion collection is invalid or full.") }
        let sources = Set(state.sources.map(\.id)), encounters = Set(state.encounters.map(\.id))
        var textCount = 0
        for session in memory.sessions {
            guard !session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, session.title.count <= 200, session.opening.count <= 5000,
                  session.questions.count <= maximumQuestions, Set(session.questions.map(\.id)).count == session.questions.count,
                  session.createdAt.timeIntervalSinceReferenceDate.isFinite, session.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  session.eventAt?.timeIntervalSinceReferenceDate.isFinite != false,
                  session.encounterID == nil || encounters.contains(session.encounterID!),
                  session.currentQuestionID == nil || session.questions.contains(where: { $0.id == session.currentQuestionID }),
                  session.capturedSourceIDs.count <= 100, Set(session.capturedSourceIDs).count == session.capturedSourceIDs.count,
                  Set(session.capturedSourceIDs).isSubset(of: sources), session.removedQuestionCount >= 0, session.removedQuestionCount <= 100_000, session.clearedAnswerCount >= 0, session.clearedAnswerCount <= 100_000,
                  (session.lastCaptureDigest == nil) == (session.lastCaptureSourceID == nil),
                  session.lastCaptureDigest == nil || (session.lastCaptureDigest!.count == 64 && session.lastCaptureDigest!.allSatisfy { $0.isHexDigit }),
                  session.lastCaptureSourceID == nil || session.capturedSourceIDs.contains(session.lastCaptureSourceID!) else { throw CareError.invalid("An appointment companion contains invalid details or missing evidence.") }
            textCount += session.title.count + session.opening.count
            for question in session.questions {
                guard !question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, question.text.count <= 2000, question.answer.count <= 10_000,
                      question.sourceIDs.count <= 100, Set(question.sourceIDs).count == question.sourceIDs.count,
                      Set(question.sourceIDs).isSubset(of: sources),
                      question.synthetic || !question.sourceIDs.contains(where: { state.source($0)?.synthetic == true }),
                      !question.editedSnapshot || question.copiedSnapshot else { throw CareError.invalid("A visit question is too long or references missing evidence.") }
                textCount += question.text.count + question.answer.count
            }
        }
        guard textCount <= maximumTextCharacters else { throw CareError.invalid("Your appointment notes are full. Export or remove an older companion before adding more.") }
    }
}
