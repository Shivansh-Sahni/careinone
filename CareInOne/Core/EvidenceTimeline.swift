import Foundation

public enum TimelineDateAxis: String, CaseIterable, Sendable {
    case event = "Medical event", effective = "Effective date", captured = "Added here", reviewed = "Reviewed here"
}
public struct TimelineEntry: Identifiable, Sendable {
    public var id: EvidenceNodeID
    public var title: String
    public var sourceID: UUID
    public var entityID: UUID?
    public var eventAt: Date?
    public var effectiveAt: Date?
    public var capturedAt: Date
    public var reviewedAt: Date?
    public var detail: String
    public func date(on axis: TimelineDateAxis) -> Date? {
        switch axis {
        case .event: eventAt
        case .effective: effectiveAt
        case .captured: capturedAt
        case .reviewed: reviewedAt
        }
    }
    /// Calendar-day distance only; capture delay is not a care delay.
    public func daysAddedAfterEvent(calendar: Calendar = .current) -> Int? {
        guard let eventAt else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: eventAt), to: calendar.startOfDay(for: capturedAt)).day ?? 0
        return days > 0 ? days : nil
    }
}
public enum EvidenceTimeline {
    public static func entries(_ state: CareState, entityID: UUID? = nil, axis: TimelineDateAxis = .event, reportsOnly: Bool = false) -> [TimelineEntry] {
        let sources = Dictionary(uniqueKeysWithValues: state.sources.map { ($0.id, $0) })
        let claims = state.claims.filter { $0.canonical && (entityID == nil || $0.entityID == entityID) }
        var entries = claims.compactMap { claim -> TimelineEntry? in
            guard let source = sources[claim.sourceID] else { return nil }
            return TimelineEntry(id: .report(claim.id), title: claim.summary, sourceID: source.id, entityID: claim.entityID,
                eventAt: claim.eventAt, effectiveAt: claim.effectiveAt, capturedAt: source.capturedAt, reviewedAt: claim.acceptedAt,
                detail: claim.action.displayLabel + " · " + claim.certainty.displayLabel + " · " + claim.provenance.displayLabel)
        }
        if !reportsOnly {
            let selectedSources = Set(claims.map(\.sourceID))
            for source in state.sources where entityID == nil || selectedSources.contains(source.id) {
                entries.append(TimelineEntry(id: .source(source.id), title: source.title, sourceID: source.id, eventAt: source.eventAt,
                    capturedAt: source.capturedAt, detail: "Preserved original · " + source.state.rawValue))
            }
        }
        return entries.sorted {
            switch ($0.date(on: axis), $1.date(on: axis)) {
            case let (a?, b?) where a != b: return a > b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return $0.id.key < $1.id.key
            }
        }
    }
}
