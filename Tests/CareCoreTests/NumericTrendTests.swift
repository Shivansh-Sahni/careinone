import Foundation
import Testing
@testable import CareCore

struct NumericTrendTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    @discardableResult private func add(_ value: Double = 12, day: Int = 0, unit: String = "g/dL", to state: inout CareState) throws -> Claim {
        let date = calendar.startOfDay(for: now).addingTimeInterval(Double(day) * 86400)
        let source = Source(title: "Fictional result", kind: .typed, text: "Fictional hemoglobin \(value) \(unit).", contentHash: UUID().uuidString, eventAt: date)
        var claim = Claim(sourceID: source.id, kind: .resultType, label: "Fictional hemoglobin", quote: source.workingText)
        claim.action = .resultAvailable; claim.numericValue = value; claim.unit = unit; claim.eventAt = date; claim.certainty = .documented
        state.sources.append(source); try Reconciler.accept([claim], into: &state, now: date)
        return try #require(state.claims.first { $0.id == claim.id })
    }
    @Test func historicalDatesRemainAndDifferentUnitsNeverMergeOrConvert() throws {
        var state = CareState()
        let old = try add(12, day: -90, to: &state)
        let recent = try add(13, day: -7, to: &state)
        _ = try add(130, day: -1, unit: "g/L", to: &state)
        let series = NumericTrendPolicy.series(in: state, calendar: calendar)
        #expect(series.count == 2)
        let gramsPerDeciliter = try #require(series.first { $0.unit == "g/dL" })
        #expect(gramsPerDeciliter.points.map(\.id) == [old.id, recent.id])
        #expect(gramsPerDeciliter.points.map(\.value) == [12, 13])
        #expect(gramsPerDeciliter.canConnectValues)
        #expect(series.first { $0.unit == "g/L" }?.points.map(\.value) == [130])
    }
    @Test func supersededResultsAreExcludedWithoutRemovingTheirSource() throws {
        var state = CareState(); let old = try add(to: &state)
        var replacement = try add(13, day: 1, to: &state)
        replacement.userEdited = true; replacement.supersedesID = old.id
        try Reconciler.accept([replacement], into: &state, now: now)
        let series = NumericTrendPolicy.series(in: state, calendar: calendar)
        #expect(series.flatMap(\.points).map(\.id) == [replacement.id])
        #expect(state.source(old.sourceID) != nil)
    }
    @Test func negatedConditionalOtherSubjectPendingAndUncertainResultsProduceTheSameEmptyStatePredicate() throws {
        var state = CareState(); let original = try add(to: &state)
        var variants: [Claim] = []
        var value = original; value.negated = true; variants.append(value)
        value = original; value.conditional = true; variants.append(value)
        value = original; value.subject = .family; variants.append(value)
        value = original; value.review = .pending; variants.append(value)
        for certainty in Certainty.allCases where ![.reported, .documented].contains(certainty) { value = original; value.certainty = certainty; variants.append(value) }
        for claim in variants { state.claims = [claim]; #expect(NumericTrendPolicy.series(in: state, calendar: calendar).isEmpty) }
        state.claims = [original]; state.claims[0].certainty = .reported
        #expect(NumericTrendPolicy.series(in: state, calendar: calendar).count == 1)
    }
    @Test func orderedPlannedAndPreliminaryValuesAreNotConfirmedAvailableResults() throws {
        var state = CareState(); let original = try add(to: &state)
        for action in ClaimAction.allCases where action != .resultAvailable {
            state.claims = [original]; state.claims[0].action = action
            #expect(NumericTrendPolicy.series(in: state, calendar: calendar).isEmpty)
        }
    }
    @Test func unresolvedDiscrepancyRetainsValuesAndSourcesButNeverConnectsThem() throws {
        var state = CareState(); let first = try add(day: -2, to: &state); let second = try add(13, day: -1, to: &state)
        let entity = try #require(first.entityID)
        state.conflicts = [Conflict(id: "fictional-discrepancy", entityID: entity, claimIDs: [first.id, second.id], reason: "Fictional source discrepancy", createdAt: now)]
        let series = try #require(NumericTrendPolicy.series(in: state, calendar: calendar).first)
        #expect(series.hasUnresolvedDiscrepancy && !series.canConnectValues)
        #expect(series.points.count == 2 && series.points.allSatisfy(\.disputed))
        #expect(series.points.allSatisfy { state.source($0.claim.sourceID) != nil })
    }
    @Test func differentValuesWithinTheSameDayAreLabeledForComparisonWithoutDeclaringAClinicalConflict() throws {
        var state = CareState(); let first = try add(to: &state); var second = try add(13, to: &state)
        second.eventAt = second.eventAt!.addingTimeInterval(3600); state.claims[state.claims.firstIndex { $0.id == second.id }!] = second
        _ = try add(14, day: 1, to: &state)
        let series = try #require(NumericTrendPolicy.series(in: state, calendar: calendar).first)
        #expect(series.hasMultipleValuesOnDate && !series.canConnectValues && !series.hasUnresolvedDiscrepancy)
        #expect(series.points.filter(\.multipleValuesOnDate).map(\.id) == [first.id, second.id])
        #expect(series.points.count == 3 && state.conflicts.isEmpty)
    }
    @Test func missingUnitsNeverImplyComparableValues() throws {
        for unit in ["", "  "] {
            var state = CareState(); _ = try add(unit: unit, to: &state); _ = try add(13, day: 1, unit: unit, to: &state)
            let series = try #require(NumericTrendPolicy.series(in: state, calendar: calendar).first)
            #expect(series.points.count == 2 && !series.canConnectValues)
        }
    }
    @Test func malformedOrDetachedEvidenceCannotReachChartValues() throws {
        var state = CareState(); let original = try add(to: &state)
        var variants: [Claim] = []
        var value = original; value.numericValue = .nan; variants.append(value)
        value = original; value.numericValue = .infinity; variants.append(value)
        value = original; value.numericValue = nil; variants.append(value)
        value = original; value.eventAt = nil; variants.append(value)
        value = original; value.quote = "unsupported fictional quotation"; variants.append(value)
        value = original; value.sourceID = UUID(); variants.append(value)
        value = original; value.entityID = UUID(); variants.append(value)
        for claim in variants { state.claims = [claim]; #expect(NumericTrendPolicy.series(in: state, calendar: calendar).isEmpty) }
    }
}
