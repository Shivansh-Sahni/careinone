import UIKit
import CareCore

@MainActor enum ExportService {
    static func briefPDF(_ state: CareState) throws -> URL {
        let text = BriefBuilder.text(state)
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            let margin: CGFloat = 44; let width = bounds.width - margin * 2
            var y: CGFloat = margin; var page = 0
            func beginPage() {
                context.beginPage(); page += 1; y = margin
                let footer = "CareContinuity · Patient-reviewed saved information · \(page)"
                footer.draw(at: CGPoint(x: margin, y: bounds.height - 28), withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
            }
            beginPage()
            // Split long lines into bounded runs, then measure and paginate every run.
            for line in text.components(separatedBy: .newlines) {
                let heading = !line.isEmpty && line == line.uppercased() && !line.hasPrefix("•")
                let attrs: [NSAttributedString.Key: Any] = [.font: heading ? UIFont.boldSystemFont(ofSize: 13) : UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black]
                let chunks = Chunker.split(line.isEmpty ? " " : line, size: 650, overlap: 0)
                for chunk in chunks {
                    let string = chunk.text as NSString
                    let measured = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    let height = ceil(measured.height) + 7
                    if y + height > bounds.height - 48 { beginPage() }
                    string.draw(in: CGRect(x: margin, y: y, width: width, height: height), withAttributes: attrs); y += height
                }
            }
        }
        return try write(data, name: "CareBrief.pdf")
    }
    static func graph(_ state: CareState) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try write(encoder.encode(state), name: "CareContinuity-graph.json")
    }
    private static func write(_ data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CareContinuityExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let url = directory.appendingPathComponent(name); try data.write(to: url, options: [.atomic, .completeFileProtection]); return url
    }
    static func clean() { try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("CareContinuityExports")) }
}
