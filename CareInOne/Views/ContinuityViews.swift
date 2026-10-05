import SwiftUI
import CareCore

struct ContinuityHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    @State private var creating = false
    @State private var includeArchived = false
    private var workspaces: [VisitWorkspace] {
        (store.state.continuity?.workspaces ?? []).filter { includeArchived || $0.progress != .archived }.sorted { $0.createdAt > $1.createdAt }
    }
    var body: some View {
        List {
            Section {
                Text("Keep the thread of each visit").font(.title2.bold())
                Text("Prepare questions, save a reference point, and review what you remember afterward. Everything stays connected to your saved evidence.").foregroundStyle(.secondary)
                Button("Start a visit workspace", systemImage: "plus.rectangle.on.folder") { creating = true }.accessibilityIdentifier("workspace-new")
                NavigationLink(value: Route.checkpoints) { Label("Care checkpoints", systemImage: "clock.arrow.circlepath") }
            }
            Section("Your visits") {
                Toggle("Include archived workspaces", isOn: $includeArchived)
                if workspaces.isEmpty { Text("Start with a question or a visit you want to remember. No medical history is required.").foregroundStyle(.secondary) }
                ForEach(workspaces) { workspace in
                    NavigationLink(value: Route.workspace(workspace.id)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(workspace.title).font(.headline)
                            Text(workspace.progress.rawValue).font(.caption).foregroundStyle(Theme.accent)
                            if !workspace.debrief.isEmpty { Label("Recollection draft saved", systemImage: "square.and.pencil").font(.caption) }
                        }
                    }
                }
            }
        }.navigationTitle("Visit workspaces")
            .sheet(isPresented: $creating) { WorkspaceEditor { navigate(.workspace($0)) } }
    }
}

struct WorkspaceEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let workspace: VisitWorkspace?
    let onSaved: (UUID) -> Void
    @State private var title: String
    @State private var encounterID: UUID?
    @State private var priorities: String
    @State private var issue: String?
    @State private var discarding = false
    init(workspace: VisitWorkspace? = nil, onSaved: @escaping (UUID) -> Void) {
        self.workspace = workspace; self.onSaved = onSaved
        _title = State(initialValue: workspace?.title ?? "")
        _encounterID = State(initialValue: workspace?.encounterID)
        _priorities = State(initialValue: workspace?.priorities ?? "")
    }
    private var hasChanges: Bool { title != (workspace?.title ?? "") || encounterID != workspace?.encounterID || priorities != (workspace?.priorities ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name this visit", text: $title).accessibilityIdentifier("workspace-title")
                Picker("Encounter", selection: $encounterID) {
                    Text("No encounter needed yet").tag(UUID?.none)
                    ForEach(store.state.encounters) { Text($0.title).tag(Optional($0.id)) }
                }
                Section("What matters to you") {
                    TextField("My priorities", text: $priorities, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("workspace-priorities")
                    Text("Personal context for preparation. This does not create clinical claims.").font(.caption).foregroundStyle(.secondary)
                }
                if let issue { Text(issue).foregroundStyle(Theme.warning) }
            }.navigationTitle(workspace == nil ? "New visit workspace" : "Edit workspace")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if hasChanges { discarding = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save workspace") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("workspace-save") }
                }
                .interactiveDismissDisabled(hasChanges)
                .alert("Discard unsaved workspace changes?", isPresented: $discarding) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                } message: { Text("Your saved visit priorities and encounter grouping stay unchanged. These edits will be lost.") }
        }
    }
    private func save() {
        var id: UUID?
        let saved = store.mutate { state in
            let savedID: UUID
            if let workspace { savedID = workspace.id }
            else { savedID = try ContinuityEngine.createWorkspace(title: title, encounterID: encounterID, in: &state) }
            guard var value = state.continuity?.workspaces.first(where: { $0.id == savedID }) else { throw CareError.invalid("The workspace was removed.") }
            value.title = title; value.encounterID = encounterID; value.priorities = priorities
            try ContinuityEngine.saveWorkspace(value, in: &state); id = savedID
        }
        if saved, let id { dismiss(); onSaved(id) } else { issue = store.error }
    }
}

struct CheckpointsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    @State private var creating = false
    var body: some View {
        List {
            Section {
                Text("A reference point for your saved care").font(.headline)
                Text("A checkpoint remembers reviewed reports and follow-through at a moment in time. Later comparisons show what was added or changed here, even when the medical event happened earlier.").font(.subheadline).foregroundStyle(.secondary)
                Button("Save a care checkpoint", systemImage: "bookmark") { creating = true }.accessibilityIdentifier("checkpoint-new")
            }
            ForEach((store.state.continuity?.checkpoints ?? []).sorted { $0.createdAt > $1.createdAt }) { checkpoint in
                NavigationLink(value: Route.checkpoint(checkpoint.id)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(checkpoint.title).font(.headline)
                        Text(checkpoint.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        Text("\(checkpoint.facts.count) reviewed reports saved").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Care checkpoints")
            .sheet(isPresented: $creating) { CheckpointEditor { navigate(.checkpoint($0)) } }
    }
}

struct CheckpointEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var checkpoint: CareCheckpoint? = nil
    var encounterID: UUID? = nil
    var workspaceID: UUID? = nil
    let onSaved: (UUID) -> Void
    @State private var title = ""
    @State private var issue: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Checkpoint name", text: $title).accessibilityIdentifier("checkpoint-title")
                Text(checkpoint == nil ? "Only reviewed reports are included. Saving this reference point does not verify clinical instructions or complete care tasks." : "Renaming preserves the original snapshot and its date.").font(.subheadline).foregroundStyle(.secondary)
                if let issue { Text(issue).foregroundStyle(Theme.warning) }
            }.navigationTitle(checkpoint == nil ? "Save checkpoint" : "Rename checkpoint")
                .onAppear { if title.isEmpty { title = checkpoint?.title ?? "Before my visit" } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save checkpoint") {
                            let id: UUID?
                            if let checkpoint { id = store.mutate { try ContinuityEngine.renameCheckpoint(checkpoint.id, title: title, in: &$0) } ? checkpoint.id : nil }
                            else { id = store.saveCheckpoint(title: title, encounterID: encounterID, workspaceID: workspaceID) }
                            if let id { dismiss(); onSaved(id) } else { issue = store.error }
                        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("checkpoint-save")
                    }
                }
        }
    }
}

struct CheckpointDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var rename = false
    @State private var deleting = false
    @State private var export: ComparisonExport?
    private var checkpoint: CareCheckpoint? { store.state.continuity?.checkpoints.first { $0.id == id } }
    var body: some View {
        Group {
            if let checkpoint {
                let comparison = ContinuityComparator.compare(checkpoint, to: store.state)
                List {
                    Section {
                        Text(checkpoint.title).font(.title2.bold())
                        Text("Reference saved " + checkpoint.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        Button("Preview comparison for export", systemImage: "square.and.arrow.up") { export = ComparisonExport(text: ContinuityComparator.text(comparison, title: checkpoint.title)) }.accessibilityIdentifier("checkpoint-export")
                    }
                    ComparisonSections(comparison: comparison)
                    Section("Reports at this checkpoint") {
                        DisclosureGroup("Browse \(checkpoint.facts.count) saved reports") {
                            ForEach(checkpoint.facts) { fact in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ContinuityComparator.describe(fact.claim, sourceTitle: fact.sourceTitle)).font(.caption).textSelection(.enabled)
                                    Text("Source version \(fact.sourceVersion). Opening the source shows its current version and available history.").font(.caption).foregroundStyle(.secondary)
                                    SourceLink(id: fact.claim.sourceID)
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                    Section {
                        Button("Rename checkpoint") { rename = true }
                        Button("Delete checkpoint", role: .destructive) { deleting = true }
                    }
                }
            } else { ContentUnavailableView("Checkpoint removed", systemImage: "bookmark.slash") }
        }.navigationTitle("Since this checkpoint").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $rename) { if let checkpoint { CheckpointEditor(checkpoint: checkpoint) { _ in } } }
            .sheet(item: $export) { ComparisonExportView(text: $0.text) }
            .confirmationDialog("Delete this checkpoint?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete checkpoint", role: .destructive) { if store.mutate({ ContinuityEngine.removeCheckpoint(id, from: &$0) }) { dismiss() } }
            } message: { Text("Your current care and original sources remain saved. Linked visit workspaces will no longer have this reference point.") }
    }
}

struct ComparisonSections: View {
    @Environment(AppStore.self) private var store
    let comparison: ContinuityComparison
    @State private var filter: ContinuityChangeKind?
    var body: some View {
        Section {
            Text("Changes in saved information").font(.headline)
            Text("This compares reviewed reports, discrepancy status, and follow-through in the app. It does not establish medical truth or the order of medical events.").font(.caption).foregroundStyle(.secondary)
            Text("\(comparison.beforeClaimCount) reviewed reports before · \(comparison.afterClaimCount) after").font(.caption)
            if comparison.includesSynthetic { Badge(text: "Includes synthetic demo evidence", caution: true) }
            if comparison.omittedDeletedSourceCount > 0 { Text("Evidence from \(comparison.omittedDeletedSourceCount) deleted source(s) was removed from this checkpoint. Comparison coverage is incomplete.").font(.subheadline).foregroundStyle(Theme.warning) }
            if comparison.differences.isEmpty { Text("No differences found in the reviewed information compared here. Unreviewed sources and events outside the app remain unknown.").accessibilityIdentifier("comparison-empty") }
            else {
                Picker("Show", selection: $filter) {
                    Text("All differences (\(comparison.differences.count))").tag(ContinuityChangeKind?.none)
                    ForEach(ContinuityChangeKind.allCases.filter { kind in comparison.differences.contains { $0.kind == kind } }, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
            }
        }
        ForEach(comparison.differences.filter { filter == nil || $0.kind == filter }) { item in
            Section(item.kind.rawValue) {
                Text(item.title).font(.headline)
                if let before = item.before { DisclosureGroup("Before") { Text(before).font(.subheadline).textSelection(.enabled) } }
                if let after = item.after { DisclosureGroup("After") { Text(after).font(.subheadline).textSelection(.enabled) } }
                Text(item.explanation).font(.caption).foregroundStyle(.secondary)
                ForEach(item.sourceIDs, id: \.self) { SourceLink(id: $0) }
                if let entityID = item.entityID, store.state.entity(entityID) != nil { NavigationLink("Open care item", value: Route.entity(entityID)) }
            }
        }
    }
}
private struct ComparisonExport: Identifiable { let id = UUID(); let text: String }
private struct ComparisonExportView: View {
    @Environment(\.dismiss) private var dismiss
    let text: String
    @State private var pdf: PreparedTextExport?
    @State private var issue: String?
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                Text("Review this complete copy before sharing. The copy can contain identifying details and cannot be remotely revoked.").font(.subheadline)
                ShareLink("Share comparison text", item: text)
                Button("Create comparison PDF") {
                    pdf?.discard(); pdf = nil; issue = nil
                    do { pdf = try ExportService.preparedPDF(text, name: "CareInOne-comparison.pdf") }
                    catch { issue = error.localizedDescription }
                }
                if let pdf, pdf.isAvailable(for: text) { ShareLink("Share comparison PDF", item: pdf.url) }
                if let issue { Text(issue).foregroundStyle(Theme.warning) }
                Text(text).font(.subheadline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }.padding() }.navigationTitle("Review before sharing")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
