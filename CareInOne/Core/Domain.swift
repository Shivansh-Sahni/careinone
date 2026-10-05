import Foundation

public enum EntityKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case medication, condition, allergy, labTest, resultType, referral, appointment, procedure, provider, instruction, followUp, administrativeTask, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .labTest: "Tests"; case .resultType: "Results"; case .followUp: "Follow-ups"
        case .administrativeTask: "Administrative"; case .provider: "Care team"; case .allergy: "Allergies"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst() + "s"
        }
    }
    public var symbol: String {
        switch self {
        case .medication: "pills"; case .condition: "heart.text.clipboard"; case .allergy: "allergens"
        case .labTest, .resultType: "testtube.2"; case .referral: "arrow.triangle.branch"
        case .appointment: "calendar"; case .procedure: "cross.case"; case .provider: "person.2"
        case .instruction: "list.clipboard"; case .followUp: "arrow.turn.down.right"
        case .administrativeTask: "doc.badge.gearshape"; case .other: "square.stack"
        }
    }
    public var consequential: Bool { [.medication, .allergy, .instruction].contains(self) }
}
public enum SourceKind: String, Codable, CaseIterable, Sendable { case voice, visitRecording, typed, photo, pdf, textFile, fhir, manual }
public enum ProcessingState: String, Codable, Sendable { case saved, pending, processing, needsReview, complete, failed, cancelled }
public enum Certainty: String, Codable, CaseIterable, Sendable { case unknown, notProvided, reported, documented, uncertain, conditional, disputed, historical, superseded, completedByUserReport }
public enum ReviewStatus: String, Codable, Sendable { case pending, accepted, edited, rejected }
public enum Provenance: String, Codable, CaseIterable, Sendable { case patientReported, documentDerived, inferred }
public enum ClaimAction: String, Codable, CaseIterable, Sendable { case mentioned, taking, started, stopped, changed, ordered, requested, scheduled, completed, resultAvailable, followUpKnown, referralPlaced, appointmentScheduled, visitCompleted, planned, prepNeeded, inProgress, dismissed }
public enum Subject: String, Codable, CaseIterable, Sendable { case patient, family, other, unknown }
public enum RelationKind: String, Codable, CaseIterable, Sendable { case sameEntity, supports, supersedes, conflictsWith, duplicateOf, completes, dependsOn, resultOf, followUpFor, orderedBy, scheduledFor }
public enum DuePrecision: String, Codable, CaseIterable, Sendable { case exact, approximate, unknown }
public enum ConflictStatus: String, Codable, Sendable { case unresolved, clarified, dismissed }
public enum LoopStatus: String, Codable, Sendable { case open, completed, uncertain, dismissed }
public enum LoopKind: String, Codable, Sendable { case test, referral, followUp, procedure, resultFollowUp, administrative }
public enum ChangeKind: String, Codable, CaseIterable, Sendable { case added, changed, superseded, conflictIntroduced, conflictResolved, loopOpened, loopClosed }
public enum Projection: String, Codable, Sendable { case current, possible, conflicting, historical, unknown }

public struct EvidencePage: Codable, Hashable, Sendable { public var number: Int; public var text: String; public init(number: Int, text: String) { self.number = number; self.text = text } }
public struct TranscriptSegment: Codable, Equatable, Sendable {
    public var text: String; public var startUTF16: Int; public var lengthUTF16: Int; public var seconds: Double
    public init(text: String, startUTF16: Int, lengthUTF16: Int, seconds: Double) { self.text = text; self.startUTF16 = startUTF16; self.lengthUTF16 = lengthUTF16; self.seconds = seconds }
}
public struct Source: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var kind: SourceKind
    public var capturedAt = Date()
    public var eventAt: Date?
    public var originalText: String
    public var workingText: String
    public var pages: [EvidencePage] = []
    public var transcriptSegments: [TranscriptSegment] = []
    public var originalFile: String?
    public var audioFile: String?
    public var contentHash: String
    public var encounterID: UUID?
    public var provider: String = ""
    public var state: ProcessingState = .saved
    public var processingMessage: String = ""
    public var version: Int = 1
    public var analysisVersion: String = ""
    public var previousText: [String] = []
    public var synthetic: Bool = false
    public init(title: String, kind: SourceKind, text: String, contentHash: String, eventAt: Date? = nil) {
        self.title = title; self.kind = kind; self.originalText = text; self.workingText = text; self.contentHash = contentHash; self.eventAt = eventAt
    }
}
public struct EncounterRecord: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var title: String; public var date: Date?; public var provider: String
    public init(title: String, date: Date? = nil, provider: String = "") { self.title = title; self.date = date; self.provider = provider }
}
public struct Entity: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var kind: EntityKind; public var label: String
    public var normalizedKey: String; public var aliases: [String] = []; public var codeSystem: String?; public var code: String?
    public init(kind: EntityKind, label: String, id: UUID = UUID()) { self.id = id; self.kind = kind; self.label = label; self.normalizedKey = Normalizer.key(label) }
}
public struct Claim: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var sourceID: UUID; public var entityID: UUID?
    public var kind: EntityKind; public var label: String; public var action: ClaimAction = .mentioned
    public var value: String = ""; public var numericValue: Double?; public var unit: String = ""
    public var route: String = ""; public var frequency: String = ""; public var form: String = ""
    public var eventAt: Date?; public var effectiveAt: Date?; public var dueAt: Date?; public var duePrecision: DuePrecision = .unknown
    public var dueTimeKnown = false
    public var intervalDays: Int?; public var quote: String; public var page: Int?; public var transcriptSeconds: Double?
    public var subject: Subject = .patient; public var speaker: String?; public var speakerUncertain: Bool = true
    public var certainty: Certainty = .reported; public var negated = false; public var conditional = false
    public var confidence: Double = 0.5; public var review: ReviewStatus = .pending; public var userEdited = false
    public var provenance: Provenance = .patientReported; public var codeSystem: String?; public var code: String?
    public var supersedesID: UUID?; public var relatedEntityID: UUID?; public var relation: RelationKind?
    public var acceptedAt: Date?; public var createdAt = Date(); public var revision: Int = 1
    public var extractionVersion: String = "local-v1"; public var clarification: String?
    public init(sourceID: UUID, kind: EntityKind, label: String, quote: String) { self.sourceID = sourceID; self.kind = kind; self.label = label; self.quote = quote }
    public var canonical: Bool { [.accepted, .edited].contains(review) && subject == .patient }
    public var needsStrongReview: Bool { kind.consequential || confidence < 0.85 || conditional || negated || subject != .patient || ![.reported, .documented].contains(certainty) }
    public var summary: String {
        [label, numericValue.map { $0.formatted(.number.precision(.fractionLength(0...4))) } ?? "", unit, value, route, frequency, form].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
public struct Relation: Codable, Identifiable, Equatable, Sendable {
    public var id: String; public var from: UUID; public var to: UUID; public var kind: RelationKind
    public init(from: UUID, to: UUID, kind: RelationKind) { self.from = from; self.to = to; self.kind = kind; id = "\(from)|\(to)|\(kind.rawValue)" }
}
public struct Conflict: Codable, Identifiable, Equatable, Sendable {
    public var id: String; public var entityID: UUID; public var claimIDs: [UUID]; public var reason: String
    public var status: ConflictStatus = .unresolved; public var note = ""; public var createdAt: Date; public var resolvedAt: Date?
    public var question: String { "My saved sources disagree about \(reason.lowercased()). Which instructions should I follow, and can my records be updated?" }
}
public struct CareLoop: Codable, Identifiable, Equatable, Sendable {
    public var id: String; public var entityID: UUID; public var kind: LoopKind; public var title: String
    public var stage: ClaimAction; public var status: LoopStatus = .open; public var claimIDs: [UUID]
    public var dueAt: Date?; public var precision: DuePrecision = .unknown; public var dueConfidence: Double = 0
    public var encounterID: UUID?; public var note: String = ""; public var userCompleted = false
    public var createdAt: Date
    public func timing(now: Date = Date()) -> String {
        guard status != .completed else { return userCompleted ? "Completed by your report" : "Completion documented in a saved source" }
        guard let dueAt else { return "No completion has been added here. Timing is not provided." }
        if precision == .exact { return dueAt < Calendar.current.startOfDay(for: now) ? "Saved due date has passed. No completion has been added here." : "Due \(dueAt.formatted(date: .abbreviated, time: .omitted))" }
        return "Around \(dueAt.formatted(date: .abbreviated, time: .omitted)). Timing is approximate."
    }
}
public struct LoopOverride: Codable, Equatable, Sendable {
    public var status: LoopStatus?; public var note = ""; public var dueAt: Date?; public var precision: DuePrecision = .unknown
    public var dateEdited = false; public var updatedAt = Date(); public var evidenceIDs: [UUID] = []
    public init() {}
}
public struct Change: Codable, Identifiable, Equatable, Sendable {
    public var id: String; public var setID: UUID; public var kind: ChangeKind; public var entityID: UUID
    public var sourceID: UUID; public var claimID: UUID; public var before: String?; public var after: String
    public var date: Date; public var category: EntityKind; public var encounterID: UUID?
}
public struct Question: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var text: String; public var entityID: UUID?; public var sourceID: UUID?; public var encounterID: UUID?
    public var answered = false; public var answer = ""; public var createdAt = Date()
    public init(text: String, entityID: UUID? = nil, sourceID: UUID? = nil, encounterID: UUID? = nil) { self.text = text; self.entityID = entityID; self.sourceID = sourceID; self.encounterID = encounterID }
}
public struct Note: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var text: String; public var entityID: UUID?; public var createdAt = Date()
    public init(text: String, entityID: UUID? = nil) { self.text = text; self.entityID = entityID }
}
public struct Profile: Codable, Equatable, Sendable {
    public var displayName = ""; public var birthDate: Date?; public var contactName = ""; public var contactPhone = ""
    public var onboarded = false; public var cloudConsent = false; public var cloudConsentAt: Date?
    public var appLock = false; public var notifications = false; public var notifyTasks = true; public var notifyAppointments = true
    public var retainAudio = false; public var demoLoaded = false
    public var ocrLanguage: String?
    public var cloudProviderConfigurationID: String?
    public init() {}
}
public struct Audit: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID(); public var timestamp = Date(); public var action: String; public var count: Int
    public init(action: String, count: Int = 1) { self.action = action; self.count = count }
}
public struct CareState: Codable, Equatable, Sendable {
    public var schemaVersion = 1; public var sources: [Source] = []; public var encounters: [EncounterRecord] = []
    public var entities: [Entity] = []; public var claims: [Claim] = []; public var relations: [Relation] = []
    public var conflicts: [Conflict] = []; public var loops: [CareLoop] = []; public var changes: [Change] = []
    public var questions: [Question] = []; public var notes: [Note] = []; public var profile = Profile(); public var audit: [Audit] = []
    public var loopOverrides: [String: LoopOverride] = [:]
    /// Optional for decoding stores and backups created before the continuity workspace existed.
    public var continuity: ContinuityMemory?
    /// Optional to preserve decoding of existing installations and encrypted archives.
    public var handoffs: HandoffMemory?
    /// Patient-controlled appointment agendas and answer drafts; optional for legacy stores.
    public var visitCompanions: VisitCompanionMemory?
    /// Practical next actions and personal check-back dates, separate from clinical instructions.
    public var followThroughPlans: FollowThroughMemory?
    public init() {}
    public func source(_ id: UUID) -> Source? { sources.first { $0.id == id } }
    public func entity(_ id: UUID?) -> Entity? { entities.first { $0.id == id } }
    public func claims(for id: UUID) -> [Claim] { claims.filter { $0.entityID == id && $0.canonical } }
    public var unsupersededClaims: [Claim] {
        let retired = Set(claims.filter(\.canonical).compactMap(\.supersedesID))
        return claims.filter { $0.canonical && $0.certainty != .superseded && !retired.contains($0.id) }
    }
    public func upcomingAppointments(now: Date = Date(), through: Date? = nil) -> [Claim] {
        unsupersededClaims.filter { claim in
            guard claim.kind == .appointment, !claim.negated, !claim.conditional,
                  ![.historical, .unknown, .notProvided].contains(claim.certainty),
                  ![.completed, .visitCompleted, .dismissed, .stopped].contains(claim.action), let date = claim.dueAt else { return false }
            return date >= (claim.dueTimeKnown ? now : Calendar.current.startOfDay(for: now)) && (through == nil || date < through!)
        }.sorted { $0.dueAt == $1.dueAt ? $0.id.uuidString < $1.id.uuidString : $0.dueAt! < $1.dueAt! }
    }
    public func projection(for id: UUID) -> Projection {
        if conflicts.contains(where: { $0.entityID == id && $0.status == .unresolved }) { return .conflicting }
        let superseded = Set(relations.filter { $0.kind == .supersedes }.map(\.to))
        let active = claims(for: id).filter { $0.certainty != .superseded && !superseded.contains($0.id) }
        guard !active.isEmpty else { return .unknown }
        if active.allSatisfy({ $0.certainty == .historical }) { return .historical }
        if active.contains(where: { $0.certainty == .uncertain || $0.conditional || $0.certainty == .disputed || $0.eventAt == nil }) { return .possible }
        if active.contains(where: { $0.certainty == .unknown || $0.certainty == .notProvided }) { return .unknown }
        return .current
    }
}
