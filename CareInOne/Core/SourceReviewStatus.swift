import Foundation

/// Current review progress is derived from saved reports, not the number first extracted.
/// The persisted processing message remains unchanged for history and recovery.
public struct SourceReviewStatus: Equatable, Sendable {
    public let pendingCount: Int
    public let savedReportCount: Int
    public let message: String

    public init(source: Source, claims: [Claim]) {
        let reports = claims.filter { $0.sourceID == source.id }
        pendingCount = reports.filter { $0.review == .pending }.count
        savedReportCount = reports.filter(\.canonical).count

        // A successful older analysis does not mean a newer request completed.
        // Keep errors, cancellation, interrupted requests, and edited-text guidance visible.
        guard source.state == .needsReview || source.state == .complete else {
            message = source.processingMessage.isEmpty ? "Your source is preserved on this device." : source.processingMessage
            return
        }

        let progress: String
        if pendingCount > 0 {
            progress = "\(pendingCount) \(pendingCount == 1 ? "proposal" : "proposals") waiting for review. Proposals enter My Care only after you accept them."
        } else if savedReportCount > 0 {
            progress = "No proposals waiting for review. \(savedReportCount) reviewed \(savedReportCount == 1 ? "report is" : "reports are") saved in My Care."
        } else {
            progress = "No proposals waiting for review. No reports from this source are saved in My Care."
        }
        let detail = Self.processingDetail(source.processingMessage, needsReview: pendingCount > 0)
        message = progress + (detail.isEmpty ? " Your original evidence remains saved." : " " + detail)
    }

    private static func processingDetail(_ savedMessage: String, needsReview: Bool) -> String {
        let trimmed = savedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "No new proposals. Your original evidence is saved." { return "" }

        // Strip only the exact app-generated historical count sentences. Preserve
        // analysis-limit warnings and FHIR unsupported-resource disclosures verbatim.
        let prefixes = [
            #"^\d+ proposals ready\. Nothing enters My Care until you review it\."#,
            #"^\d+ (supported items|new proposals)\."#
        ]
        for prefix in prefixes {
            if let range = trimmed.range(of: prefix, options: .regularExpression) {
                var detail = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let instruction = " Confirm subject and extraction."
                if !needsReview, detail.hasSuffix(instruction) { detail.removeLast(instruction.count) }
                return detail
            }
        }
        if !needsReview, trimmed == "Your answers are saved. Review extracted information before it updates My Care." {
            return "Your visit answers remain saved."
        }
        if !needsReview, trimmed == "Patient-saved reply. Review extracted reports before they enter care memory; this does not verify the speaker or medical correctness." {
            return "Patient-saved reply. Reviewing an extraction does not verify the speaker or medical correctness."
        }
        return trimmed
    }
}
