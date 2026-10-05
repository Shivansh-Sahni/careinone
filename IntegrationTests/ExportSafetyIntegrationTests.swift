import XCTest
import PDFKit
import CareCore
@testable import CareContinuity

@MainActor final class ExportSafetyIntegrationTests: XCTestCase {
    func testRepeatedGraphPreparationCannotOverwriteAnEarlierSharedCopy() throws {
        var first = CareState(); first.profile.displayName = "Fictional first patient"
        let original = try ExportService.graph(first); track(original)
        let originalBytes = try Data(contentsOf: original)
        var second = first; second.profile.displayName = "Fictional later profile"
        let later = try ExportService.graph(second); track(later)
        XCTAssertNotEqual(original, later)
        XCTAssertEqual(original.lastPathComponent, later.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        XCTAssertEqual(try JSONDecoder().decode(CareState.self, from: originalBytes).profile.displayName, "Fictional first patient")
        XCTAssertEqual(try JSONDecoder().decode(CareState.self, from: Data(contentsOf: later)).profile.displayName, "Fictional later profile")
    }

    func testRepeatedPDFPreparationPreservesTheEarlierFileAndExactContentBinding() throws {
        let first = try ExportService.preparedPDF("Fictional earlier copy: bring records.", name: "Shared-care.pdf"); track(first.url)
        let firstBytes = try Data(contentsOf: first.url)
        let later = try ExportService.preparedPDF("Fictional later copy: new question.", name: "Shared-care.pdf"); track(later.url)
        XCTAssertNotEqual(first.url, later.url)
        XCTAssertEqual(try Data(contentsOf: first.url), firstBytes)
        XCTAssertTrue(first.isAvailable(for: "Fictional earlier copy: bring records."))
        XCTAssertFalse(first.isAvailable(for: "Fictional later copy: new question."))
        let readable = try XCTUnwrap(PDFDocument(url: first.url)?.string)
        XCTAssertTrue(readable.contains("Fictional earlier copy")); XCTAssertFalse(readable.contains("Fictional later copy"))
        XCTAssertFalse(readable.contains("Patient-reviewed"))
    }

    func testEditedMultilineOrUnicodeContentCannotReuseAnEarlierPreparedPDF() throws {
        let text = "Fictional résumé\n  Questions for tomorrow\nBring records."
        let prepared = try ExportService.preparedPDF(text, name: "Outgoing.pdf"); track(prepared.url)
        XCTAssertTrue(prepared.isAvailable(for: text))
        XCTAssertFalse(prepared.isAvailable(for: text.replacingOccurrences(of: "  Questions", with: "Questions")))
        XCTAssertFalse(prepared.isAvailable(for: text.replacingOccurrences(of: "résumé", with: "resume")))
        XCTAssertFalse(prepared.isAvailable(for: text + "\nA newly edited question"))
        try FileManager.default.removeItem(at: prepared.url)
        XCTAssertFalse(prepared.isAvailable(for: text))
    }

    func testDiscardingOnePreparedCopyDoesNotRemoveAnotherSharePreparation() throws {
        let text = "Fictional handoff copy"
        let first = try ExportService.preparedPDF(text, name: "Handoff.pdf"); track(first.url)
        let second = try ExportService.preparedPDF(text, name: "Handoff.pdf"); track(second.url)
        first.discard()
        XCTAssertFalse(first.isAvailable(for: text)); XCTAssertTrue(second.isAvailable(for: text))
    }

    func testPDFPaginationPreservesEveryCompleteEvidenceRow() throws {
        let rows = (0..<3200).map { String(format: "Fictional-row-%04d: bring this question to the visit.", $0) }
        let text = "FICTIONAL REVIEW COPY\n\n" + rows.joined(separator: "\n")
        let url = try ExportService.textPDF(text, name: "Long-evidence.pdf"); track(url)
        let pdf = try XCTUnwrap(PDFDocument(url: url)); XCTAssertGreaterThan(pdf.pageCount, 3)
        let readable = try XCTUnwrap(pdf.string)
        let pattern = try NSRegularExpression(pattern: "Fictional-row-[0-9]{4}")
        let found = pattern.matches(in: readable, range: NSRange(readable.startIndex..<readable.endIndex, in: readable)).map { (readable as NSString).substring(with: $0.range) }
        XCTAssertEqual(found.count, rows.count)
        XCTAssertEqual(Set(found).count, rows.count)
        XCTAssertTrue(readable.contains("Fictional-row-0000")); XCTAssertTrue(readable.contains("Fictional-row-3199"))
    }

    func testUnsupportedExportNamesCannotChangeAnExistingPreparedCopy() throws {
        let existing = try ExportService.preparedPDF("Fictional existing copy", name: "Existing.pdf"); track(existing.url)
        let bytes = try Data(contentsOf: existing.url)
        for name in ["", ".", "..", "../Existing.pdf", "nested/Existing.pdf", "nested\\Existing.pdf", "bad\nname.pdf"] {
            XCTAssertThrowsError(try ExportService.textPDF("Fictional new copy", name: name)) { error in
                XCTAssertTrue(error.localizedDescription.contains("filename"))
            }
        }
        XCTAssertEqual(try Data(contentsOf: existing.url), bytes)
    }

    func testEmptyAndOversizedPDFsFailClearlyWithoutDamagingAnExistingCopy() throws {
        let text = "Fictional copy to retain"
        let existing = try ExportService.preparedPDF(text, name: "Existing.pdf"); track(existing.url)
        XCTAssertThrowsError(try ExportService.preparedPDF(" \n\t ", name: "Empty.pdf"))
        XCTAssertThrowsError(try ExportService.preparedPDF(String(repeating: "x", count: ExportService.maxPDFCharacters + 1), name: "Oversized.pdf")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Share its text"))
        }
        XCTAssertTrue(existing.isAvailable(for: text))
    }

    func testPDFPageLimitFailsInsteadOfReturningATruncatedDocument() throws {
        let text = Array(repeating: "Fictional evidence row with a visit question.", count: 14_000).joined(separator: "\n")
        XCTAssertLessThan(text.utf16.count, ExportService.maxPDFCharacters)
        XCTAssertThrowsError(try ExportService.textPDF(text, name: "Too-many-pages.pdf")) { error in
            XCTAssertTrue(error.localizedDescription.contains("PDF pages"))
            XCTAssertTrue(error.localizedDescription.contains("Share its text"))
        }
    }

    private func track(_ url: URL) {
        let directory = url.deletingLastPathComponent()
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    }
}
