import Foundation
import CryptoKit
import CommonCrypto
import Security

/// A complete portable snapshot. Secrets and device authentication credentials are never included.
public struct CareArchive: Codable, Sendable {
    public var version = 1
    public var createdAt = Date()
    public var state: CareState
    public var files: [String: Data]
    public init(state: CareState, files: [String: Data]) { self.state = state; self.files = files }

    public func validate() throws {
        guard version == 1, state.schemaVersion == 1 else { throw CareError.invalid("This backup requires a newer CareContinuity version.") }
        guard state.sources.count <= 10_000, state.claims.count <= 100_000,
              files.values.reduce(0, { $0 + $1.count }) <= ArchiveCodec.maxFileBytes else { throw CareError.invalid("This backup exceeds the supported size limit.") }
        func unique<T: Hashable>(_ ids: [T]) throws { guard Set(ids).count == ids.count else { throw CareError.invalid("The backup contains duplicate records.") } }
        try unique(state.sources.map(\.id)); try unique(state.claims.map(\.id)); try unique(state.entities.map(\.id))
        try unique(state.encounters.map(\.id)); try unique(state.questions.map(\.id)); try unique(state.notes.map(\.id)); try unique(state.audit.map(\.id))
        try unique(state.conflicts.map(\.id)); try unique(state.loops.map(\.id)); try unique(state.changes.map(\.id)); try unique(state.relations.map(\.id))
        let expected = Set(state.sources.flatMap { [$0.originalFile, $0.audioFile].compactMap { $0 } })
        guard expected == Set(files.keys), files.keys.allSatisfy({ !$0.isEmpty && !$0.contains("/") && !$0.contains("\\") && !$0.contains("..") }) else {
            throw CareError.invalid("The backup’s original evidence is missing or has invalid file references.")
        }
        let sources = Dictionary(uniqueKeysWithValues: state.sources.map { ($0.id, $0) })
        let entities = Set(state.entities.map(\.id)); let encounters = Set(state.encounters.map(\.id))
        for source in state.sources {
            if let id = source.encounterID, !encounters.contains(id) { throw CareError.invalid("The backup has a missing encounter.") }
        }
        for claim in state.claims {
            guard let source = sources[claim.sourceID] else { throw CareError.invalid("The backup has a claim without source evidence.") }
            if let id = claim.entityID, !entities.contains(id) { throw CareError.invalid("The backup has a missing care item.") }
            if claim.canonical {
                guard claim.entityID != nil else { throw CareError.invalid("A reviewed claim is missing its care item.") }
                try ProposalValidator.validate(claim, source: source)
            }
        }
    }
}

public enum ArchiveCodec {
    public static let maxFileBytes = 40_000_000
    public static let maxArchiveBytes = 110_000_000
    private static let rounds: UInt32 = 600_000
    public static func readFile(_ url: URL, limit: Int = maxArchiveBytes) throws -> Data {
        guard limit >= 0 else { throw CareError.invalid("Invalid backup file limit.") }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(1_000_000, limit - data.count + 1)), !chunk.isEmpty {
            guard chunk.count <= limit - data.count else { throw CareError.invalid("This file exceeds the supported backup size limit.") }
            data.append(chunk)
        }
        return data
    }
    private struct Envelope: Codable {
        var format = "carecontinuity-encrypted-backup"
        var version = 1
        var algorithm = "PBKDF2-SHA256-AES256-GCM"
        var rounds: UInt32
        var salt: Data
        var sealed: Data
    }
    public static func encrypt(_ archive: CareArchive, passphrase: String) throws -> Data {
        try validatePassphrase(passphrase); try archive.validate()
        let plaintext = try JSONEncoder().encode(archive)
        guard plaintext.count <= 80_000_000 else { throw CareError.invalid("This backup is too large. Remove unneeded retained audio and try again.") }
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { throw CareError.invalid("Could not create a secure backup salt.") }
        let key = try derive(passphrase, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: Data("carecontinuity-backup-v1".utf8))
        guard let combined = sealed.combined else { throw CareError.invalid("Could not encrypt this backup.") }
        return try JSONEncoder().encode(Envelope(rounds: rounds, salt: salt, sealed: combined))
    }
    public static func decrypt(_ data: Data, passphrase: String) throws -> CareArchive {
        guard data.count <= maxArchiveBytes else { throw CareError.invalid("This backup exceeds the supported size limit.") }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw CareError.invalid("This file is not a supported encrypted CareContinuity backup.") }
        guard envelope.format == "carecontinuity-encrypted-backup", envelope.version == 1,
              envelope.algorithm == "PBKDF2-SHA256-AES256-GCM", envelope.rounds == rounds, envelope.salt.count == 32 else {
            throw CareError.invalid("This backup’s format or encryption settings are unsupported.")
        }
        try validatePassphrase(passphrase)
        let plaintext: Data
        do {
            let key = try derive(passphrase, salt: envelope.salt)
            plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.sealed), using: key, authenticating: Data("carecontinuity-backup-v1".utf8))
        } catch { throw CareError.invalid("The passphrase did not unlock this backup, or the file was changed or damaged. Your current records have not been replaced.") }
        guard plaintext.count <= 80_000_000 else { throw CareError.invalid("The decrypted backup exceeds the supported size limit.") }
        let archive = try JSONDecoder().decode(CareArchive.self, from: plaintext)
        try archive.validate()
        return archive
    }
    public static func validatePassphrase(_ passphrase: String) throws {
        guard passphrase.count >= 12, passphrase.utf8.count <= 1024, !passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CareError.invalid("Use a passphrase of at least 12 characters (up to 1,024 UTF-8 bytes). Keep it somewhere safe; the app cannot recover it.")
        }
    }
    private static func derive(_ passphrase: String, salt: Data) throws -> SymmetricKey {
        var derived = Data(count: 32)
        let password = Array(passphrase.utf8)
        let status = derived.withUnsafeMutableBytes { output in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self), password.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                        output.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard status == kCCSuccess else { throw CareError.invalid("Could not derive the backup encryption key.") }
        return SymmetricKey(data: derived)
    }
}
