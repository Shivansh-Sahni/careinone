import Foundation

public struct NumericTrendPoint: Identifiable, Equatable, Sendable {
    public let claim: Claim
    public let value: Double
    public let date: Date
    public let disputed: Bool
    public let multipleValuesOnDate: Bool
    public var id: UUID { claim.id }
}

public struct NumericTrendSeries: Identifiable, Equatable, Sendable {
    public let entity: Entity
    public let unit: String
    public let points: [NumericTrendPoint]
    public var id: String { entity.id.uuidString + "|" + unit }
    public var hasUnresolvedDiscrepancy: Bool { points.contains(where: \.disputed) }
    public var hasMultipleValuesOnDate: Bool { points.contains(where: \.multipleValuesOnDate) }
    /// A line expresses comparability, never a diagnosis or clinical winner.
    public var canConnectValues: Bool {
        points.count > 1 && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasUnresolvedDiscrepancy && !hasMultipleValuesOnDate
    }
}

/// Only explicit available results become a numeric series. Unknown or retired
/// reports stay accessible in Sources and My Care rather than appearing settled.
public enum NumericTrendPolicy {
    public static func series(in state: CareState, calendar: Calendar = .current) -> [NumericTrendSeries] {
        let eligible = state.unsupersededClaims.filter { claim in
            guard [.labTest, .resultType].contains(claim.kind), claim.action == .resultAvailable,
                  [.reported, .documented].contains(claim.certainty), !claim.negated, !claim.conditional,
                  let value = claim.numericValue, value.isFinite,
                  let date = claim.eventAt, date.timeIntervalSince1970.isFinite,
                  let entity = state.entity(claim.entityID), [.labTest, .resultType].contains(entity.kind),
                  let source = state.source(claim.sourceID), !claim.quote.isEmpty,
                  source.workingText.contains(claim.quote) else { return false }
            return true
        }
        let disputed = Set(state.conflicts.filter { $0.status == .unresolved }.flatMap(\.claimIDs))
        var result: [NumericTrendSeries] = []
        for entity in state.entities where [.labTest, .resultType].contains(entity.kind) {
            let claims = eligible.filter { $0.entityID == entity.id }
            for unit in Set(claims.map(\.unit)).sorted() {
                let values = claims.filter { $0.unit == unit }.sorted {
                    $0.eventAt == $1.eventAt ? $0.id.uuidString < $1.id.uuidString : $0.eventAt! < $1.eventAt!
                }
                let byDay = Dictionary(grouping: values) { calendar.startOfDay(for: $0.eventAt!) }
                // Different results within one day may both be correct. The model
                // cannot distinguish repeats from contradictions, so label them
                // for source comparison instead of inventing a clinical conflict.
                let repeatedDays = Set(byDay.compactMap { day, claims in Set(claims.compactMap(\.numericValue)).count > 1 ? day : nil })
                let points = values.map { claim in
                    NumericTrendPoint(claim: claim, value: claim.numericValue!, date: claim.eventAt!, disputed: disputed.contains(claim.id), multipleValuesOnDate: repeatedDays.contains(calendar.startOfDay(for: claim.eventAt!)))
                }
                result.append(NumericTrendSeries(entity: entity, unit: unit, points: points))
            }
        }
        return result.sorted {
            let ordering = $0.entity.label.localizedStandardCompare($1.entity.label)
            return ordering == .orderedSame ? $0.id < $1.id : ordering == .orderedAscending
        }
    }
}
