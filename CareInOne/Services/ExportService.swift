import UIKit
import CoreText
import CryptoKit
import CareCore

/// A prepared PDF represents exact text, not a mutable filename shared by other exports.
struct PreparedTextExport: Equatable {
    let url: URL
    private let digest: Data
    fileprivate init(url: URL, text: String) { self.url = url; digest = Data(SHA256.hash(data: Data(text.utf8))) }
    func isAvailable(for text: String) -> Bool {
        digest == Data(SHA256.hash(data: Data(text.utf8))) && FileManager.default.isReadableFile(atPath: url.path)
    }
    func discard() { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
}

@MainActor enum ExportService {
    static let maxPDFCharacters = 1_000_000
    static let maxPDFPages = 200
    static func preparedPDF(_ text: String, name: String) throws -> PreparedTextExport {
        PreparedTextExport(url: try textPDF(text, name: name), text: text)
    }
    static func briefPDF(_ state: CareState) throws -> URL {
        try textPDF(BriefBuilder.text(state), name: "CareBrief.pdf")
    }
    static func textPDF(_ text: String, name: String) throws -> URL {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CareError.invalid("There is no text to put in a PDF. Add content before preparing it.") }
        guard text.utf16.count <= maxPDFCharacters else { throw CareError.invalid("This copy is too long for a PDF. Share its text or choose fewer items for a visit packet.") }
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 44
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 4
        let attributed = NSMutableAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black, .paragraphStyle: paragraph])
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { line, range, _, _ in
            if let line, !line.isEmpty, line == line.uppercased(), !line.hasPrefix("•") {
                attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 13), range: NSRange(range, in: text))
            }
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: margin, y: 48, width: bounds.width - 2 * margin, height: bounds.height - margin - 48), transform: nil)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        var failure: String?
        let data = renderer.pdfData { context in
            var offset = 0; var page = 0
            while offset < attributed.length {
                guard page < maxPDFPages else { failure = "This copy needs more than \(maxPDFPages) PDF pages. Share its text or choose fewer visit-packet items instead."; break }
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else { failure = "This text could not be laid out safely in a PDF. Share the text instead."; break }
                context.beginPage(); page += 1
                let footer = "CareInOne · Shared care information · \(page)"
                footer.draw(at: CGPoint(x: margin, y: bounds.height - 28), withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                let drawing = context.cgContext
                drawing.saveGState(); drawing.textMatrix = .identity; drawing.translateBy(x: 0, y: bounds.height); drawing.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, drawing); drawing.restoreGState()
                offset = visible.location + visible.length
            }
        }
        if let failure { throw CareError.invalid(failure) }
        return try write(data, name: name)
    }
    static func practiceFiles() throws -> [URL] {
        let text = "SYNTHETIC PRACTICE RECORD — fictional patient\nAllergy: latex.\nCBC ordered.\nReferral to physical therapy requested."
        let textURL = try write(Data(text.utf8), name: "Synthetic-practice-note.txt")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            context.beginPage()
            (text as NSString).draw(in: CGRect(x: 40, y: 60, width: 532, height: 600), withAttributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black])
        }
        let pdfURL = try write(pdf, name: "Synthetic-practice-document.pdf")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            (text as NSString).draw(in: CGRect(x: 60, y: 80, width: 1080, height: 740), withAttributes: [.font: UIFont.systemFont(ofSize: 38), .foregroundColor: UIColor.black])
        }
        guard let png = image.pngData() else { throw CareError.invalid("Could not create the practice image.") }
        let imageURL = try write(png, name: "Synthetic-practice-photo.png")
        let fhir = #"{"resourceType":"Bundle","type":"collection","entry":[{"resource":{"resourceType":"Patient","id":"practice-patient","name":[{"text":"Synthetic Practice Patient"}]}},{"resource":{"resourceType":"Observation","id":"practice-result","status":"final","subject":{"reference":"Patient/practice-patient"},"code":{"text":"Hemoglobin"},"effectiveDateTime":"2026-09-01","valueQuantity":{"value":13.2,"unit":"g/dL"}}}]}"#
        return [textURL, pdfURL, imageURL, try write(Data(fhir.utf8), name: "Synthetic-practice-patient.json")]
    }
    static func sourceText(_ source: Source) throws -> URL {
        try write(Data(source.originalText.utf8), name: "CareInOne-source-\(source.id.uuidString.prefix(8)).txt")
    }
    static func graph(_ state: CareState) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try write(encoder.encode(state), name: "CareInOne-graph.json")
    }
    nonisolated static func encryptedBackup(_ data: Data) throws -> URL { try write(data, name: "CareInOne-\(UUID().uuidString.prefix(8)).carebackup") }
    private nonisolated static func write(_ data: Data, name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"), !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CareError.invalid("The export filename is unsupported. Your existing files have not been changed.")
        }
        // A share sheet may still hold an earlier URL when another export is prepared.
        // Keep the human-readable filename, but never replace that earlier file's bytes.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneExports", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let url = directory.appendingPathComponent(name)
        do { try data.write(to: url, options: [.atomic, .completeFileProtection]); return url }
        catch { try? FileManager.default.removeItem(at: directory); throw error }
    }
    static func clean(root: URL = FileManager.default.temporaryDirectory) {
        // Erasing/restoring care must also remove copies exported before the product rename.
        for name in ["CareInOneExports", "CareContinuityExports"] {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
        }
    }
}
