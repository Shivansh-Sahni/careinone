import SwiftUI
import CareCore

struct VisitWorkspaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.careNavigate) private var navigate
    let id: UUID
    @State private var editing = false
    @State private var checkpointSheet = false
    @State private var debriefSheet = false
    @State private var deleting = false
    private var workspace: VisitWorkspace? { store.state.continuity?.workspaces.first { $0.id == id } }
    var body: some View {
        Group {
            if let workspace {
                List {
                    overview(workspace)
                    referencePoint(workspace)
                    Section("After the visit") {
                        Button(workspace.debrief.isEmpty ? "Capture what I remember" : "Continue saved recollection", systemImage: "square.and.pencil") { debriefSheet = true }.accessibilityIdentifier("workspace-debrief")
                        Text("Save what you heard as patient-reported evidence. Extracted claims still need review; questions remain questions.").font(.caption).foregroundStyle(.secondary)
                        ForEach(workspace.debriefSourceIDs, id: \.self) { SourceLink(id: $0) }
                        Button("Add another source", systemImage: "plus") { store.openAdd(.text, encounterID: workspace.encounterID) }
                    }
                    ReadinessSections(encounterID: workspace.encounterID)
                    Section {
                        NavigationLink("All questions", value: Route.questions(nil))
                        NavigationLink("Manage follow-through", value: Route.loops)
                        Button("Delete workspace", role: .destructive) { deleting = true }
                    }
                }
            } else { ContentUnavailableView("Workspace removed", systemImage: "folder.badge.minus") }
        }.navigationTitle("Visit workspace").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) { if let workspace { WorkspaceEditor(workspace: workspace) { _ in } } }
            .sheet(isPresented: $checkpointSheet) { CheckpointEditor(encounterID: workspace?.encounterID, workspaceID: id) { _ in } }
            .sheet(isPresented: $debriefSheet) { if let workspace { VisitDebriefView(workspace: workspace) { if let sourceID = $0 { navigate(.source(sourceID)) } } } }
            .confirmationDialog("Delete this visit workspace?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete workspace and its draft", role: .destructive) { if store.mutate({ ContinuityEngine.removeWorkspace(id, from: &$0) }) { dismiss() } }
            } message: { Text("This removes its priorities and unsaved recollection draft. Original sources, questions, checkpoints, and reviewed care remain saved.") }
    }
    private func overview(_ workspace: VisitWorkspace) -> some View {
        Section {
            Text(workspace.title).font(.title2.bold())
            if !workspace.priorities.isEmpty { Text(workspace.priorities).textSelection(.enabled) }
            Button("Edit title, encounter, or priorities") { editing = true }
            Picker("My progress", selection: Binding(get: { self.workspace?.progress ?? .preparing }, set: { progress in
                guard var current = self.workspace else { return }; current.progress = progress; store.saveWorkspace(current)
            })) { ForEach(VisitProgress.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Text("You choose this organizational status. It does not confirm attendance, agreement with an instruction, or completion of medical care.").font(.caption).foregroundStyle(.secondary)
            NavigationLink { VisitPacketView(encounterID: workspace.encounterID) } label: { Label("Choose a visit packet", systemImage: "list.bullet.clipboard") }
            if let encounterID = workspace.encounterID { NavigationLink("Encounter and its sources", value: Route.prepare(encounterID)) }
        }
    }
    private func referencePoint(_ workspace: VisitWorkspace) -> some View {
        Section("Your reference point") {
            if let checkpoint = store.state.continuity?.checkpoints.first(where: { $0.id == workspace.checkpointID }) {
                NavigationLink(value: Route.checkpoint(checkpoint.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What changed since \(checkpoint.title)?").font(.headline)
                        Text("\(ContinuityComparator.compare(checkpoint, to: store.state).differences.count) differences in reviewed information").font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("workspace-compare")
            } else { Text("Save what is known here before the visit, then compare it with your later reviewed information.").font(.subheadline).foregroundStyle(.secondary) }
            Button(workspace.checkpointID == nil ? "Save my starting point" : "Save a new reference point", systemImage: "bookmark") { checkpointSheet = true }.accessibilityIdentifier("workspace-checkpoint")
            let checkpoints = store.state.continuity?.checkpoints ?? []
            if !checkpoints.isEmpty {
                Picker("Use an existing checkpoint", selection: Binding(get: { self.workspace?.checkpointID }, set: { checkpointID in
                    guard var current = self.workspace else { return }; current.checkpointID = checkpointID; store.saveWorkspace(current)
                })) { Text("No checkpoint linked").tag(UUID?.none); ForEach(checkpoints) { Text($0.title).tag(Optional($0.id)) } }
            }
        }
    }
}

struct ReadinessSections: View {
    @Environment(AppStore.self) private var store
    let encounterID: UUID?
    @State private var editingQuestion: Question?
    private var items: [ReadinessItem] { VisitReadiness.items(store.state, encounterID: encounterID) }
    var body: some View {
        Section("Evidence to carry forward") {
            Text("A checklist of saved context, not a health score. Unresolved records and unfinished work from earlier encounters remain visible.").font(.caption).foregroundStyle(.secondary)
            if items.isEmpty { Text("No open items have been identified in the information saved here. This does not mean your care is complete.") }
        }
        ForEach(ReadinessKind.allCases, id: \.self) { kind in
            let group = items.filter { $0.kind == kind }
            if !group.isEmpty {
                Section {
                    DisclosureGroup("\(kind.rawValue) · \(group.count)") {
                        ForEach(group) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title).font(.headline)
                                Text(item.explanation).font(.caption).foregroundStyle(.secondary)
                                ForEach(item.sourceIDs, id: \.self) { SourceLink(id: $0) }
                                if let questionID = item.questionID { Button("Write an answer or edit question") { editingQuestion = store.state.questions.first { $0.id == questionID } } }
                                if kind == .disagreement { NavigationLink("Compare the reports", value: Route.conflicts) }
                                if kind == .followThrough { NavigationLink("Review follow-through", value: Route.loops) }
                                if kind == .uncertain {
                                    Button("Save a clarification question") { store.addQuestion("Can we clarify what was reported about \(item.title)?", entity: item.entityID, source: item.sourceIDs.first, encounter: encounterID) }
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingQuestion) { QuestionEditor(question: $0) }
    }
}

struct VisitDebriefView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let workspace: VisitWorkspace
    let onSaved: (UUID?) -> Void
    @State private var draft: VisitDebriefDraft
    @State private var discard = false
    @State private var issue: String?
    private enum DraftField: Hashable { case heard, nextSteps, questions }
    @FocusState private var editingField: DraftField?
    init(workspace: VisitWorkspace, onSaved: @escaping (UUID?) -> Void) {
        self.workspace = workspace; self.onSaved = onSaved; _draft = State(initialValue: workspace.debrief)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("In your own words").font(.title2.bold())
                    Text("Capture as little as you remember. These are your recollections, not clinician-verified instructions. Unknown details can stay blank.").font(.subheadline).foregroundStyle(.secondary)
                    OptionalDateField(title: "Visit date", date: $draft.eventAt)
                }
                Section("What I heard") { TextEditor(text: $draft.heard).frame(minHeight: 100).focused($editingField, equals: .heard).accessibilityLabel("What I heard").accessibilityIdentifier("debrief-heard") }
                Section("Next steps as I remember them") { TextEditor(text: $draft.nextSteps).frame(minHeight: 90).focused($editingField, equals: .nextSteps).accessibilityLabel("Next steps as I remember them").accessibilityIdentifier("debrief-next") }
                Section("Questions I still have") {
                    TextEditor(text: $draft.questions).frame(minHeight: 90).focused($editingField, equals: .questions).accessibilityLabel("Questions I still have").accessibilityIdentifier("debrief-questions")
                    Text("One question per line. Questions are saved separately so they cannot be mistaken for clinical instructions.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Save evidence and review", systemImage: "doc.badge.plus") {
                        let result = store.saveDebrief(draft, workspaceID: workspace.id)
                        if result.saved { dismiss(); onSaved(result.sourceID) } else { issue = store.error }
                    }.disabled(draft.isEmpty).accessibilityIdentifier("debrief-save-evidence")
                    Button("Save draft and close") { saveDraft() }.accessibilityIdentifier("debrief-save-draft")
                    Text("Saving a draft keeps it only in this workspace. Saving evidence creates a source; proposed care updates still need your review. It does not complete tasks or resolve discrepancies.").font(.caption).foregroundStyle(.secondary)
                    if let issue { Text(issue).foregroundStyle(Theme.warning) }
                }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Remember this visit").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled(draft != workspace.debrief)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if draft != workspace.debrief { discard = true } else { dismiss() } } }
                    if editingField != nil {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done editing recollection") { editingField = nil }.accessibilityIdentifier("debrief-text-done")
                        }
                    }
                }
                .confirmationDialog("Save your recollection draft?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Save draft") { saveDraft() }
                    Button("Discard these edits", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
        }
    }
    private func saveDraft() {
        guard var current = store.state.continuity?.workspaces.first(where: { $0.id == workspace.id }) else { issue = "This workspace was removed."; return }
        current.debrief = draft
        if store.saveWorkspace(current) { dismiss() } else { issue = store.error }
    }
}
