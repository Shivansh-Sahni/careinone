import Foundation

extension RelationKind {
    public var displayLabel: String {
        switch self {
        case .sameEntity: "same care item"
        case .supports: "supports"
        case .supersedes: "explicitly replaces"
        case .conflictsWith: "differs from"
        case .duplicateOf: "duplicate of"
        case .completes: "documents completion of"
        case .dependsOn: "depends on"
        case .resultOf: "result of"
        case .followUpFor: "follow-up for"
        case .orderedBy: "ordered by"
        case .scheduledFor: "scheduled for"
        }
    }
}

/// User-facing wording stays separate from stable Codable wire values.
public extension RawRepresentable where RawValue == String {
    var displayLabel: String {
        switch rawValue {
        case "typed": return "Typed recap"
        case "voice": return "Voice update"
        case "visitRecording": return "Visit recording"
        case "pdf": return "PDF"
        case "fhir": return "FHIR import"
        case "textFile": return "Text file"
        case "notProvided": return "Not provided"
        case "completedByUserReport": return "Completed by your report"
        case "patientReported": return "Patient reported"
        case "documentDerived": return "From a document"
        case "needsReview": return "Ready for review"
        case "possible": return "Possibly current"
        case "conflicting": return "Conflicting reports"
        default:
            let words = rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).lowercased()
            return words.prefix(1).uppercased() + words.dropFirst()
        }
    }
}
