import Foundation
import Testing
@testable import CareCore

struct ArchiveTests {
    private let password = "correct horse local care"
    @Test func fileReaderEnforcesLimitEvenWithoutSizeMetadata() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("123456".utf8).write(to: url)
        #expect(try ArchiveCodec.readFile(url, limit: 6) == Data("123456".utf8))
        #expect(throws: Error.self) { try ArchiveCodec.readFile(url, limit: 5) }
    }
    @Test func encryptedRoundTripPreservesEvidenceAndDecisions() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        state.sources[0].originalFile = "original.pdf"
        let archive = CareArchive(state: state, files: ["original.pdf": Data("Original evidence".utf8)])
        let encrypted = try ArchiveCodec.encrypt(archive, passphrase: password)
        #expect(!String(decoding: encrypted, as: UTF8.self).contains("metoprolol"))
        let restored = try ArchiveCodec.decrypt(encrypted, passphrase: password)
        #expect(restored.state == state); #expect(restored.files == archive.files)
    }
    @Test func wrongPasswordOrTamperingCannotRestore() throws {
        let encrypted = try ArchiveCodec.encrypt(CareArchive(state: CareState(), files: [:]), passphrase: password)
        #expect(throws: Error.self) { try ArchiveCodec.decrypt(encrypted, passphrase: "a different password") }
        var object = try #require(JSONSerialization.jsonObject(with: encrypted) as? [String: Any])
        var sealed = try #require(Data(base64Encoded: object["sealed"] as? String ?? ""))
        sealed[sealed.count / 2] ^= 1; object["sealed"] = sealed.base64EncodedString()
        let changed = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: Error.self) { try ArchiveCodec.decrypt(changed, passphrase: password) }
    }
    @Test func randomSaltAndNonceProduceDifferentBackups() throws {
        let archive = CareArchive(state: CareState(), files: [:])
        #expect(try ArchiveCodec.encrypt(archive, passphrase: password) != ArchiveCodec.encrypt(archive, passphrase: password))
    }
    @Test func rejectsDuplicateIDsMissingFilesAndTraversal() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        state.sources.append(state.sources[0])
        #expect(throws: Error.self) { try CareArchive(state: state, files: [:]).validate() }
        state.sources.removeLast(); state.sources[0].originalFile = "missing.pdf"
        #expect(throws: Error.self) { try CareArchive(state: state, files: [:]).validate() }
        state.sources[0].originalFile = "../outside"
        #expect(throws: Error.self) { try CareArchive(state: state, files: ["../outside": Data()]).validate() }
    }
    @Test func rejectsUnsupportedVersionWeakPassphraseAndOrphanClaim() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        state.sources.removeAll()
        #expect(throws: Error.self) { try CareArchive(state: state, files: [:]).validate() }
        var archive = CareArchive(state: CareState(), files: [:]); archive.version = 99
        #expect(throws: Error.self) { try archive.validate() }
        #expect(throws: Error.self) { try ArchiveCodec.encrypt(CareArchive(state: CareState(), files: [:]), passphrase: "short") }
    }
}
