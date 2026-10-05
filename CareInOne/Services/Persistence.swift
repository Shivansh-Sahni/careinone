import Foundation
import SwiftData
import CareCore

protocol StoredRecord: PersistentModel { var key: String { get set }; var payload: Data { get set }; init(key: String, payload: Data) }
@Model final class EvidenceSource: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class Encounter: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class CareEntity: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class CareClaim: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class ClaimRelation: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class ConflictRecord: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class OpenLoop: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class ChangeRecord: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class SavedQuestion: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class PatientNote: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class PatientProfile: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }
@Model final class AuditEvent: StoredRecord { @Attribute(.unique) var key: String; var payload: Data; init(key: String, payload: Data) { self.key = key; self.payload = payload } }

private struct Preferences: Codable {
    var schemaVersion = 1
    var profile: Profile
    var loopOverrides: [String: LoopOverride]
    var continuity: ContinuityMemory?
    var handoffs: HandoffMemory?
    var visitCompanions: VisitCompanionMemory?
    var followThroughPlans: FollowThroughMemory?
}
@MainActor protocol CareRepository { func load() throws -> CareState; func save(_ state: CareState) throws }
@MainActor final class SwiftDataRepository: CareRepository {
    let container: ModelContainer
    let context: ModelContext
    init(root: URL, inMemory: Bool = false) throws {
        let schema = Schema([EvidenceSource.self, Encounter.self, CareEntity.self, CareClaim.self, ClaimRelation.self, ConflictRecord.self, OpenLoop.self, ChangeRecord.self, SavedQuestion.self, PatientNote.self, PatientProfile.self, AuditEvent.self])
        let config = inMemory ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) : ModelConfiguration(schema: schema, url: root.appendingPathComponent("CareContinuity.store"), cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config]); context = ModelContext(container); context.autosaveEnabled = false
    }
    func load() throws -> CareState {
        var state = CareState()
        state.sources = try read(EvidenceSource.self); state.encounters = try read(Encounter.self); state.entities = try read(CareEntity.self)
        state.claims = try read(CareClaim.self); state.relations = try read(ClaimRelation.self); state.conflicts = try read(ConflictRecord.self)
        state.loops = try read(OpenLoop.self); state.changes = try read(ChangeRecord.self); state.questions = try read(SavedQuestion.self); state.notes = try read(PatientNote.self); state.audit = try read(AuditEvent.self)
        let preferences: [Preferences] = try read(PatientProfile.self)
        if let prefs = preferences.first {
            guard prefs.schemaVersion == 1 else { throw CareError.invalid("This database uses a newer version. Update CareInOne to open it.") }
            state.profile = prefs.profile; state.loopOverrides = prefs.loopOverrides; state.continuity = prefs.continuity; state.handoffs = prefs.handoffs
            state.visitCompanions = prefs.visitCompanions; state.followThroughPlans = prefs.followThroughPlans
        }
        return state
    }
    private func read<T: StoredRecord, V: Decodable>(_ type: T.Type) throws -> [V] { try context.fetch(FetchDescriptor<T>()).map { try JSONDecoder().decode(V.self, from: $0.payload) } }
    func save(_ state: CareState) throws {
        do {
            try sync(EvidenceSource.self, values: state.sources); try sync(Encounter.self, values: state.encounters); try sync(CareEntity.self, values: state.entities)
            try sync(CareClaim.self, values: state.claims); try sync(ClaimRelation.self, values: state.relations); try sync(ConflictRecord.self, values: state.conflicts)
            try sync(OpenLoop.self, values: state.loops); try sync(ChangeRecord.self, values: state.changes); try sync(SavedQuestion.self, values: state.questions)
            try sync(PatientNote.self, values: state.notes); try sync(AuditEvent.self, values: Array(state.audit.suffix(1000)))
            let data = try JSONEncoder().encode(Preferences(profile: state.profile, loopOverrides: state.loopOverrides, continuity: state.continuity, handoffs: state.handoffs, visitCompanions: state.visitCompanions, followThroughPlans: state.followThroughPlans))
            if let record = try context.fetch(FetchDescriptor<PatientProfile>()).first { record.payload = data }
            else { context.insert(PatientProfile(key: "local", payload: data)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
    private func sync<T: StoredRecord, V: Encodable & Identifiable>(_ type: T.Type, values: [V]) throws {
        var existing = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<T>()).map { ($0.key, $0) })
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        for value in values {
            let key = String(describing: value.id), data = try encoder.encode(value)
            if let record = existing.removeValue(forKey: key) { if record.payload != data { record.payload = data } }
            else { context.insert(T(key: key, payload: data)) }
        }
        for record in existing.values { context.delete(record) }
    }
}

@MainActor final class EvidenceVault {
    let root: URL
    let files: URL
    init(root override: URL? = nil) throws {
        root = try override ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("CareContinuity", isDirectory: true)
        files = root.appendingPathComponent("Evidence", isDirectory: true)
        for var url in [root, files] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var flags = URLResourceValues(); flags.isExcludedFromBackup = true; try url.setResourceValues(flags)
        }
    }
    func write(_ data: Data, extension ext: String) throws -> String {
        let safeExt = ext.filter { $0.isLetter || $0.isNumber }.prefix(12)
        let name = UUID().uuidString + "." + safeExt
        try data.write(to: files.appendingPathComponent(name), options: [.atomic, .completeFileProtection]); return name
    }
    func url(_ name: String) throws -> URL {
        guard !name.contains("/"), !name.contains(".."), !name.isEmpty else { throw CareError.invalid("Invalid evidence path.") }
        return files.appendingPathComponent(name)
    }
    func remove(_ name: String?) throws { if let name { let url = try url(name); if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) } } }
    func removeOrphans(state: CareState) throws {
        let keep = Set(state.sources.flatMap { [$0.originalFile, $0.audioFile].compactMap { $0 } })
        for url in try FileManager.default.contentsOfDirectory(at: files, includingPropertiesForKeys: nil) where !keep.contains(url.lastPathComponent) { try FileManager.default.removeItem(at: url) }
    }
}
