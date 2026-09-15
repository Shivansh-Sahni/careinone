import SwiftUI
import CareCore

struct ConflictsView: View {
    @Environment(AppStore.self) private var store
    @State private var all = false
    @State private var selected: Conflict?
    var body: some View {
        List {
            Section { Text("These sources differ. CareContinuity cannot determine which clinical instruction is correct. Bring both to your care team.").font(.subheadline).foregroundStyle(.secondary); Toggle("Include clarified & dismissed", isOn: $all) }
            let conflicts = store.state.conflicts.filter { all || $0.status == .unresolved }.sorted { $0.createdAt > $1.createdAt }
            if conflicts.isEmpty { ContentUnavailableView("No discrepancies in this view", systemImage: "text.bubble", description: Text("This only reflects information saved here. It is not a medical all-clear.")) }
            ForEach(conflicts) { conflict in
                Button { selected = conflict } label: { VStack(alignment: .leading, spacing: 8) { Text(conflict.reason).font(.headline); Badge(text: conflict.status.displayLabel, caution: conflict.status == .unresolved); Text("Compare \(conflict.claimIDs.count) source-linked reports").font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain)
            }
        }.navigationTitle("Records to Clarify").sheet(item: $selected) { ConflictDetailView(conflict: $0) }
    }
}
struct ConflictDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let conflict: Conflict
    @State private var note = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(conflict.reason).font(.title2.bold())
                    Text("Both reports stay in your care history. Your confirmation of what you take does not verify a provider’s record.").font(.subheadline).foregroundStyle(.secondary)
                    let claims = store.state.claims.filter { conflict.claimIDs.contains($0.id) }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top) { ForEach(claims) { side($0).frame(minWidth: 280) } }
                        VStack(spacing: 14) { ForEach(claims) { side($0) } }
                    }
                    CareCard { Label("A question to bring", systemImage: "questionmark.bubble").font(.headline); Text(conflict.question); Button("Save this question") { store.addQuestion(conflict.question, entity: conflict.entityID, source: claims.first?.sourceID) } }
                    CareCard {
                        Text("What did you clarify?").font(.headline)
                        TextField("Your resolution note", text: $note, axis: .vertical).lineLimit(3...8)
                        Text("Marking clarified closes this inbox item. It does not overwrite either clinical claim. New contradictory evidence can create a new discrepancy.").font(.caption).foregroundStyle(.secondary)
                        Button("Mark clarified") { if store.resolve(conflict, status: .clarified, note: note) { dismiss() } }.buttonStyle(.borderedProminent).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Dismiss from inbox") { if store.resolve(conflict, status: .dismissed, note: note) { dismiss() } }
                        if conflict.status != .unresolved { Button("Reopen discrepancy") { if store.resolve(conflict, status: .unresolved, note: note) { dismiss() } } }
                    }
                }.padding(20)
            }.background(Theme.background).navigationTitle("Compare sources").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }.careDestinations()
        }.onAppear { note = conflict.note }
    }
    private func side(_ claim: Claim) -> some View {
        CareCard {
            ClaimSummary(claim: claim)
            Text("“\(claim.quote)”").font(.subheadline).textSelection(.enabled)
            if let source = store.source(claim.sourceID) {
                Text(source.provider.isEmpty ? "Provider not provided" : source.provider).font(.caption).foregroundStyle(.secondary)
                Text("Captured \(source.capturedAt.formatted(date: .abbreviated, time: .omitted)) · \(source.kind.displayLabel)").font(.caption).foregroundStyle(.secondary)
            }
            SourceLink(id: claim.sourceID)
        }
    }
}
struct LoopsView: View {
    @Environment(AppStore.self) private var store
    @State private var all = false
    @State private var selected: CareLoop?
    var body: some View {
        List {
            Section { Text("Follow-through is based on explicit saved requests. Missing information remains unknown.").font(.subheadline).foregroundStyle(.secondary); Toggle("Include completed & dismissed", isOn: $all) }
            let loops = store.state.loops.filter { all || [.open, .uncertain].contains($0.status) }.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            if loops.isEmpty { ContentUnavailableView("No open steps saved here", systemImage: "checklist", description: Text("Add an order, referral, or follow-up request to track it.")) }
            ForEach(loops) { loop in
                Button { selected = loop } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(loop.title).font(.headline); HStack { Badge(text: loop.status.displayLabel, caution: loop.status == .uncertain); Text(loop.stage.displayLabel).font(.caption).foregroundStyle(.secondary) }; Text(loop.timing()).font(.subheadline).foregroundStyle(.secondary) }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Follow-through").sheet(item: $selected) { LoopDetailView(loop: $0) }
    }
}
struct LoopDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let loop: CareLoop
    @State private var note = ""
    @State private var due: Date?
    @State private var precision: DuePrecision = .unknown
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(loop.title).font(.title2.bold()); Badge(text: loop.stage.displayLabel)
                    Text(loop.timing()).font(.subheadline).foregroundStyle(.secondary)
                    Text("Due-date confidence: \(Int(loop.dueConfidence * 100))% · \(loop.precision.displayLabel)").font(.caption).foregroundStyle(.secondary)
                }
                Section("Progress through saved evidence") {
                    ForEach(LoopEngine.states(loop.kind), id: \.self) { stage in HStack { Image(systemName: stage == loop.stage ? "circle.inset.filled" : "circle"); Text(stage.displayLabel) }.foregroundStyle(stage == loop.stage ? Theme.accent : .secondary) }
                    Text("Stages only advance from accepted evidence or your explicit completion report. No completion added here does not mean it did not happen.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Your updates") {
                    TextField("Notes", text: $note, axis: .vertical).lineLimit(3...8)
                    OptionalDateField(title: "Due date", date: $due)
                    Picker("Precision", selection: $precision) { ForEach(DuePrecision.allCases, id: \.self) { Text($0.displayLabel).tag($0) } }
                    Button("Save notes & date") { save(nil) }
                    Button("I completed this") { save(.completed) }.buttonStyle(.borderedProminent)
                    Button("I’m unsure whether this is complete") { save(.uncertain) }
                    if loop.status != .open { Button("Reopen this step") { save(.open) } }
                    Button("Dismiss this step") { save(.dismissed) }
                }
                Section("Supporting sources") {
                    ForEach(store.state.claims.filter { loop.claimIDs.contains($0.id) }) { claim in VStack(alignment: .leading, spacing: 8) { ClaimSummary(claim: claim); SourceLink(id: claim.sourceID) } }
                    if let encounter = loop.encounterID { NavigationLink("Related encounter", value: Route.prepare(encounter)) }
                }
            }.navigationTitle("Follow-through detail").navigationBarTitleDisplayMode(.inline).careDestinations().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }.onAppear { note = loop.note; due = loop.dueAt; precision = loop.precision }
    }
    private func save(_ status: LoopStatus?) { let previous = store.state.loopOverrides[loop.id]; if store.setLoop(loop, status: status ?? previous?.status, note: note, due: due, precision: due == nil ? .unknown : precision, dateEdited: due != loop.dueAt || precision != loop.precision || previous?.dateEdited == true) { dismiss() } }
}
