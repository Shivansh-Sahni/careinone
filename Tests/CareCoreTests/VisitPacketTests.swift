import Foundation
import Testing
@testable import CareCore

struct VisitPacketTests {
    @Test func identityAndPrivateNotesAreExcludedUnlessSelected() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        state.profile.displayName = "PRIVATE PATIENT NAME"; state.profile.contactName = "PRIVATE CONTACT"
        state.profile.birthDate = Date(timeIntervalSince1970: 1_234_567)
        state.notes.append(Note(text: "PRIVATE NOTE CONTENT"))
        let items = VisitPacketBuilder.items(state)
        var options = PacketOptions(); options.selectedIDs = VisitPacketBuilder.suggestedSelection(items)
        let text = VisitPacketBuilder.text(state, items: items, options: options)
        #expect(!text.contains("PRIVATE PATIENT NAME")); #expect(!text.contains("PRIVATE CONTACT"))
        #expect(!text.contains("PRIVATE NOTE CONTENT")); #expect(!text.contains("DOB:"))
        options.includeName = true; options.includeContact = true; options.includeBirthDate = true
        options.selectedIDs.insert("note:" + state.notes[0].id.uuidString)
        let selected = VisitPacketBuilder.text(state, items: items, options: options)
        #expect(selected.contains("PRIVATE PATIENT NAME")); #expect(selected.contains("PRIVATE CONTACT"))
        #expect(selected.contains("PRIVATE NOTE CONTENT")); #expect(selected.contains("DOB:"))
    }
    @Test func medicationSelectionKeepsAllDifferingReportsAndEvidence() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        let items = VisitPacketBuilder.items(state)
        let medication = try #require(items.first { $0.section == .care && $0.title.lowercased().contains("metoprolol") })
        var options = PacketOptions(); options.selectedIDs = [medication.id]
        let text = VisitPacketBuilder.text(state, items: items, options: options)
        #expect(text.contains("25")); #expect(text.contains("50"))
        #expect(text.contains("not a verified current regimen")); #expect(text.contains("SYNTHETIC"))
        #expect(medication.sourceIDs.count >= 2)
        #expect(!text.contains("PRIVATE NOTE"))
    }
    @Test func upcomingVisitIncludesEarlierUnfinishedWorkButFiltersOtherQuestions() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        let next = EncounterRecord(title: "Future visit")
        state.encounters.append(next)
        state.questions = [Question(text: "General question"), Question(text: "This visit", encounterID: next.id), Question(text: "Another visit", encounterID: UUID())]
        let items = VisitPacketBuilder.items(state, encounterID: next.id)
        #expect(items.contains { $0.section == .loops })
        #expect(items.contains { $0.title == "General question" })
        #expect(items.contains { $0.title == "This visit" })
        #expect(!items.contains { $0.title == "Another visit" })
    }
    @Test func dateFilterNeverHidesUnresolvedWorkAndPendingClaimsAreExcluded() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        let since = Date.distantFuture
        let source = try #require(state.sources.first)
        state.claims.append(Claim(sourceID: source.id, kind: .medication, label: "Pending secret", quote: source.workingText))
        let items = VisitPacketBuilder.items(state, since: since)
        #expect(!items.contains { $0.section == .changes })
        #expect(items.contains { $0.section == .conflicts })
        #expect(!items.contains { $0.detail.contains("Pending secret") })
        #expect(items.contains { $0.section == .loops })
    }
    @Test func emptySelectionDoesNotLeakOtherItemsOrClaimAllClear() throws {
        var state = CareState(); try SyntheticDemo.load(into: &state)
        var options = PacketOptions(); options.asMessage = true
        let text = VisitPacketBuilder.text(state, items: VisitPacketBuilder.items(state), options: options)
        #expect(text.contains("No items selected")); #expect(text.contains("DRAFT FOR MY CARE TEAM"))
        #expect(!text.lowercased().contains("metoprolol")); #expect(!text.contains("DOB:"))
    }
}
