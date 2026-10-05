import SwiftUI
import CareCore

struct ConflictsView: View {
    @Environment(AppStore.self) private var store
    @State private var all = false
    @State private var selected: Conflict?
    var body: some View {
        List {
            Section { Text("These sources differ. CareInOne cannot determine which clinical instruction is correct. Bring both to your care team.").font(.subheadline).foregroundStyle(.secondary); Toggle("Include clarified & dismissed", isOn: $all) }
            let conflicts = store.state.conflicts.filter { all || $0.status == .unresolved }.sorted { $0.createdAt > $1.createdAt }
            if conflicts.isEmpty { ContentUnavailableView("No discrepancies in this view", systemImage: "text.bubble", description: Text("This only reflects information saved here. It is not a medical all-clear.")) }
            ForEach(conflicts) { conflict in
                Button { selected = conflict } label: { VStack(alignment: .leading, spacing: 8) { Text(conflict.reason).font(.headline); Badge(text: conflict.status.displayLabel, caution: conflict.status == .unresolved); Text("Compare \(conflict.claimIDs.count) source-linked reports").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
        }.navigationTitle("Records to Clarify").sheet(item: $selected) { ConflictDetailView(conflict: $0) }
    }
}
struct ConflictDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let conflict: Conflict
    @State private var note = ""
    @State private var discarding = false
    @FocusState private var editingNote: Bool
    private var hasChanges: Bool { note != conflict.note }
    init(conflict: Conflict) { self.conflict = conflict; _note = State(initialValue: conflict.note) }
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
                        TextField("Your resolution note", text: $note, axis: .vertical).lineLimit(3...8).focused($editingNote).accessibilityIdentifier("conflict-resolution-note")
                        Text("Marking clarified closes this inbox item. It does not overwrite either clinical claim. New contradictory evidence can create a new discrepancy.").font(.caption).foregroundStyle(.secondary)
                        Button("Mark clarified") { if store.resolve(conflict, status: .clarified, note: note) { dismiss() } }.buttonStyle(.borderedProminent).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Dismiss from inbox") { if store.resolve(conflict, status: .dismissed, note: note) { dismiss() } }
                        if conflict.status != .unresolved { Button("Reopen discrepancy") { if store.resolve(conflict, status: .unresolved, note: note) { dismiss() } } }
                    }
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(Theme.background).navigationTitle("Compare sources").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { if hasChanges { discarding = true } else { dismiss() } } }
                if editingNote { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing resolution note") { editingNote = false }.accessibilityIdentifier("conflict-resolution-note-done") } }
            }.careDestinations()
        }.interactiveDismissDisabled(hasChanges)
            .alert("Discard your unsaved resolution note?", isPresented: $discarding) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("Your saved clarification status and supporting reports will stay unchanged. Choose Mark clarified or Dismiss from inbox to save this note with a decision.") }
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
                VStack(alignment: .leading, spacing: 12) {
                    Button { selected = loop } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(loop.title).font(.headline); HStack { Badge(text: loop.status.displayLabel, caution: loop.status == .uncertain); Text(loop.stage.displayLabel).font(.caption).foregroundStyle(.secondary) }; Text(loop.timing()).font(.subheadline).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                    NavigationLink(value: Route.followThroughHelp(loop.id)) { Label("Help me get this done", systemImage: "arrow.forward.circle") }.font(.subheadline).accessibilityIdentifier("loop-help-" + loop.id)
                }.padding(.vertical, 4)
            }
            let currentIDs = Set(store.state.loops.map(\.id))
            let paused = (store.state.followThroughPlans?.plans ?? []).filter { !currentIDs.contains($0.loopID) }
            if !paused.isEmpty {
                Section("Your saved next steps") {
                    Text("Some supporting information changed or needs review. Your drafts and contact history are still here.").font(.caption).foregroundStyle(.secondary)
                    ForEach(paused) { plan in
                        NavigationLink(value: Route.followThroughHelp(plan.loopID)) {
                            Label(plan.savedTitle ?? "Continue a saved plan", systemImage: "pause.circle")
                        }.accessibilityIdentifier("loop-paused-" + plan.id.uuidString)
                    }
                }
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
    @State private var discarding = false
    @FocusState private var editingNote: Bool
    private var hasChanges: Bool { note != loop.note || due != loop.dueAt || precision != loop.precision }
    init(loop: CareLoop) {
        self.loop = loop; _note = State(initialValue: loop.note); _due = State(initialValue: loop.dueAt); _precision = State(initialValue: loop.precision)
    }
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
                    TextField("Notes", text: $note, axis: .vertical).lineLimit(3...8).focused($editingNote).accessibilityIdentifier("loop-update-note")
                    OptionalDateField(title: "Due date", date: $due)
                    Picker("Precision", selection: $precision) { ForEach(DuePrecision.allCases, id: \.self) { Text($0.displayLabel).tag($0) } }.accessibilityIdentifier("loop-update-precision")
                    Button("Save notes & date") { save(nil) }.accessibilityIdentifier("loop-update-save")
                    Button("I completed this") { save(.completed) }.buttonStyle(.borderedProminent)
                    Button("I’m unsure whether this is complete") { save(.uncertain) }
                    if loop.status != .open { Button("Reopen this step") { save(.open) } }
                    Button("Dismiss this step") { save(.dismissed) }
                }
                Section("Supporting sources") {
                    ForEach(store.state.claims.filter { loop.claimIDs.contains($0.id) }) { claim in VStack(alignment: .leading, spacing: 8) { ClaimSummary(claim: claim); SourceLink(id: claim.sourceID) } }
                    if let encounter = loop.encounterID { NavigationLink("Related encounter", value: Route.prepare(encounter)) }
                }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Follow-through detail").navigationBarTitleDisplayMode(.inline).careDestinations().toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { if hasChanges { discarding = true } else { dismiss() } } }
                if editingNote { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing follow-through note") { editingNote = false }.accessibilityIdentifier("loop-update-note-done") } }
            }
        }.interactiveDismissDisabled(hasChanges)
            .alert("Discard your unsaved follow-through updates?", isPresented: $discarding) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("The note, due date, and precision you last saved will stay unchanged. Choose Save notes & date to keep these edits.") }
    }
    private func save(_ status: LoopStatus?) { let previous = store.state.loopOverrides[loop.id]; if store.setLoop(loop, status: status ?? previous?.status, note: note, due: due, precision: due == nil ? .unknown : precision, dateEdited: due != loop.dueAt || precision != loop.precision || previous?.dateEdited == true) { dismiss() } }
}
