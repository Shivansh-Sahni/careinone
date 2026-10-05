import SwiftUI
import CareCore

struct HandoffsView: View {
    @Environment(AppStore.self) private var store
    @State private var includeFinished = false
    var body: some View {
        let items = (store.state.handoffs?.handoffs ?? []).filter { includeFinished || $0.finishedAt == nil }.sorted { $0.createdAt > $1.createdAt }
        List {
            Section {
                Text("Keep track of what you carried forward").font(.headline)
                Text("Save a selected packet, record when you share it, and preserve replies for review. Later evidence can change what you want to bring next time.").foregroundStyle(.secondary)
                NavigationLink { VisitPacketView() } label: { Label("Choose a new handoff packet", systemImage: "plus.rectangle.on.folder") }.accessibilityIdentifier("handoff-new")
                Toggle("Include finished handoffs", isOn: $includeFinished)
            }
            ForEach(items) { handoff in
                NavigationLink(value: Route.handoff(handoff.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(handoff.title).font(.headline)
                        if !handoff.recipient.isEmpty { Text("For: " + handoff.recipient).font(.subheadline) }
                        Text(handoff.statusLabel + " · " + handoff.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        if handoff.redactedAt != nil { Badge(text: "Outgoing copy removed with source", caution: true) }
                        else if let changes = try? HandoffEngine.changes(for: handoff, in: store.state), !changes.isEmpty { Badge(text: "Saved information has changed", caution: true) }
                        if !handoff.replyDraft.isEmpty { Label("Reply draft saved", systemImage: "square.and.pencil").font(.caption) }
                    }
                }.accessibilityIdentifier("handoff-row-" + handoff.title)
            }
            if items.isEmpty { Text("No handoffs in this view. Start with one question or a few selected records; a complete history is not required.").foregroundStyle(.secondary) }
        }.navigationTitle("Tracked handoffs").navigationBarTitleDisplayMode(.inline)
    }
}

struct HandoffCreateView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let options: PacketOptions
    let onSaved: (UUID) -> Void
    @State private var title = ""
    @State private var recipient = ""
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name this handoff", text: $title).accessibilityIdentifier("handoff-title")
                    TextField("Who is it for? (optional)", text: $recipient).accessibilityIdentifier("handoff-recipient")
                    Text("This saves the selected outgoing copy on your device. No message is sent. Sharing remains your choice.").font(.caption).foregroundStyle(.secondary)
                }
                Section("What is tracked") {
                    Text("\(options.selectedIDs.count) selected packet items")
                    Text("New reviewed reports for the selected care items, reviewed content and metadata in supporting sources, and linked discrepancies and follow-through. Unselected context is never added to the outgoing copy.").font(.subheadline)
                    Text("A content digest identifies this exact copy. It does not prove medical accuracy, authorship, or delivery.").font(.caption).foregroundStyle(.secondary)
                }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
            }.navigationTitle("Save tracked handoff").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save handoff") {
                        if let id = store.createHandoff(title: title, recipient: recipient, options: options) { dismiss(); onSaved(id) }
                        else { failure = store.error }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("handoff-save") }
                }
        }
    }
}

struct HandoffDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.careNavigate) private var navigate
    let id: UUID
    @State private var showSnapshot = false
    @State private var reply = false
    @State private var deleting = false
    @State private var finishing = false
    private var handoff: CareHandoff? { store.state.handoffs?.handoffs.first { $0.id == id } }
    var body: some View {
        Group {
            if let handoff {
                List {
                    Section {
                        Text(handoff.title).font(.title2.bold())
                        if !handoff.recipient.isEmpty { Text("For: " + handoff.recipient) }
                        Badge(text: handoff.statusLabel)
                        Text("Prepared " + handoff.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        if handoff.synthetic { Badge(text: "Contains synthetic demo information", caution: true) }
                        if handoff.snapshotText != nil {
                            Button("Review exact outgoing copy", systemImage: "doc.text.magnifyingglass") { showSnapshot = true }.accessibilityIdentifier("handoff-snapshot")
                            if handoff.sharedAt == nil {
                                Button("I shared this copy", systemImage: "paperplane") { _ = store.mutate { try HandoffEngine.recordShared(id, in: &$0) } }.accessibilityIdentifier("handoff-shared")
                            }
                        } else {
                            Text("The outgoing copy was removed because supporting evidence was deleted. Create a new packet from the remaining information. Copies already shared outside the app cannot be recalled.").foregroundStyle(Theme.warning).accessibilityIdentifier("handoff-redacted")
                        }
                        if let date = handoff.sharedAt { Text("You recorded sharing on " + date.formatted(date: .abbreviated, time: .shortened) + ". No delivery or read receipt is implied.").font(.caption).foregroundStyle(.secondary) }
                    }
                    Section("Since this outgoing copy") {
                        driftRows(handoff, sinceFinished: false)
                        NavigationLink { VisitPacketView(encounterID: handoff.encounterID, initialSelection: Set(handoff.selectedItemIDs)) } label: { Label("Choose an updated packet", systemImage: "doc.badge.plus") }
                        Text("An updated packet starts with earlier selections that are still available. Review any new details before sharing. The earlier copy stays unchanged.").font(.caption).foregroundStyle(.secondary)
                    }
                    if handoff.finishedAt != nil {
                        Section("Since you finished this handoff") {
                            driftRows(handoff, sinceFinished: true)
                            Button("Reopen handoff") { _ = store.mutate { try HandoffEngine.reopen(id, in: &$0) } }.accessibilityIdentifier("handoff-reopen")
                        }
                    }
                    Section("Save what came back") {
                        Button(handoff.replyDraft.isEmpty ? "Add a reply or recollection" : "Continue saved reply draft", systemImage: "square.and.pencil") { reply = true }.accessibilityIdentifier("handoff-reply")
                        Text("Patient-saved replies enter as evidence for extraction and review. They do not automatically settle a discrepancy or complete a task.").font(.caption).foregroundStyle(.secondary)
                        ForEach(handoff.replySourceIDs, id: \.self) { SourceLink(id: $0) }
                    }
                    Section("Manage this handoff") {
                        if handoff.finishedAt == nil { Button("Mark handoff finished") { finishing = true }.accessibilityIdentifier("handoff-finish") }
                        Text("Finished means you are done organizing this handoff. It does not mark medical care complete or confirm a clinician response.").font(.caption).foregroundStyle(.secondary)
                        Button("Delete handoff", role: .destructive) { deleting = true }
                    }
                }
            } else { ContentUnavailableView("Handoff removed", systemImage: "doc.badge.ellipsis") }
        }.navigationTitle("Handoff").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSnapshot) { HandoffSnapshotView(id: id) }
            .sheet(isPresented: $reply) { if let handoff { HandoffReplyView(handoff: handoff) { navigate(.source($0)) } } }
            .confirmationDialog("Finish organizing this handoff?", isPresented: $finishing, titleVisibility: .visible) {
                Button("Finish handoff") { _ = store.mutate { try HandoffEngine.finish(id, in: &$0) } }
            } message: { Text("Care tasks, questions and discrepancies keep their existing status. You can reopen this handoff.") }
            .confirmationDialog("Delete this handoff and its outgoing copy?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete handoff", role: .destructive) { if store.mutate({ HandoffEngine.remove(id, from: &$0) }) { ExportService.clean(); dismiss() } }
            } message: { Text("Its reply draft and local tracking will be removed. Saved source evidence and replies already captured as sources remain. External copies cannot be recalled.") }
    }
    @ViewBuilder private func driftRows(_ handoff: CareHandoff, sinceFinished: Bool) -> some View {
        switch Result(catching: { try HandoffEngine.changes(for: handoff, in: store.state, sinceFinished: sinceFinished) }) {
        case .success(let changes):
            if handoff.redactedAt != nil { Text("Comparison coverage is incomplete after source deletion.").font(.caption).foregroundStyle(Theme.warning) }
            if changes.isEmpty {
                Text("No differences detected in the reviewed context compared here. Unreviewed sources and outside events remain unknown.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("\(changes.count) changes in saved information").font(.headline).accessibilityIdentifier(sinceFinished ? "handoff-finish-drift" : "handoff-drift")
                Text("These may be edits or newly added older records, not new medical events. Removed evidence does not mean care was stopped or completed.").font(.caption).foregroundStyle(.secondary)
                ForEach(changes.prefix(100)) { change in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(change.kind.rawValue).font(.caption).foregroundStyle(Theme.accent)
                        Text(change.categoryLabel).font(.caption).foregroundStyle(.secondary)
                        Text(change.title).font(.subheadline)
                        ForEach(change.sourceIDs, id: \.self) { SourceLink(id: $0) }
                    }
                }
                if changes.count > 100 { Text("First 100 changes shown. Build an updated packet to review the current selection.").font(.caption) }
            }
        case .failure(let error): Text("Comparison unavailable: " + error.localizedDescription).foregroundStyle(Theme.warning)
        }
    }
}

private struct HandoffSnapshotView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var pdf: PreparedTextExport?
    @State private var failure: String?
    private var handoff: CareHandoff? { store.state.handoffs?.handoffs.first { $0.id == id } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let handoff, let text = handoff.snapshotText {
                        Text("This is the exact saved outgoing copy. Later changes to your care do not rewrite it. Review identifying details and evidence before sharing.").font(.subheadline)
                        ShareLink("Share exact text", item: text)
                        Button("Create handoff PDF") {
                            pdf?.discard(); pdf = nil; failure = nil
                            do { pdf = try ExportService.preparedPDF(text, name: "CareInOne-handoff-\(id.uuidString).pdf") }
                            catch { failure = error.localizedDescription }
                        }.accessibilityIdentifier("handoff-pdf")
                        if let pdf, pdf.isAvailable(for: text) { ShareLink("Share handoff PDF", item: pdf.url) }
                        if let failure { Text(failure).foregroundStyle(Theme.warning) }
                        DisclosureGroup("Copy identifier") {
                            Text(handoff.snapshotDigest).font(.caption.monospaced()).textSelection(.enabled)
                            Text("SHA-256 of this exact text. This identifies the copy; it is not a signature, medical verification, or proof of delivery.").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(text).font(.subheadline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("handoff-snapshot-text")
                    } else { Text("This outgoing copy is no longer available. Return to the handoff to create a new packet.") }
                }.padding()
            }.navigationTitle("Exact outgoing copy").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: handoff?.snapshotText) { _, _ in pdf?.discard(); pdf = nil; failure = nil }
        }
    }
}

private struct HandoffReplyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let handoff: CareHandoff
    let onCaptured: (UUID) -> Void
    @State private var text: String
    @State private var eventAt: Date?
    @State private var synthetic = false
    @State private var discard = false
    @State private var failure: String?
    init(handoff: CareHandoff, onCaptured: @escaping (UUID) -> Void) {
        self.handoff = handoff; self.onCaptured = onCaptured
        _text = State(initialValue: handoff.replyDraft); _eventAt = State(initialValue: handoff.replyEventAt)
        _synthetic = State(initialValue: handoff.replySynthetic ?? false)
    }
    private var dirty: Bool { text != handoff.replyDraft || eventAt != handoff.replyEventAt || synthetic != (handoff.replySynthetic ?? false) }
    var body: some View {
        NavigationStack {
            Form {
                Section("What I want to preserve") {
                    Text("Paste a reply or write what you remember. For photos, PDFs or recordings, use Add and preserve the original source.").font(.subheadline)
                    TextEditor(text: $text).frame(minHeight: 200).accessibilityLabel("Reply or recollection").accessibilityIdentifier("handoff-reply-text")
                    OptionalDateField(title: "Reply event date", date: $eventAt)
                    Toggle("This reply is synthetic demo material", isOn: $synthetic)
                }
                Section {
                    Button("Save reply as evidence", systemImage: "doc.badge.plus") {
                        if let id = store.captureHandoffReply(text, eventAt: eventAt, handoffID: handoff.id, synthetic: synthetic) { dismiss(); onCaptured(id) }
                        else { failure = store.error }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("handoff-reply-capture")
                    Text("This saves your text exactly, then proposes extractions for your review. Saving does not verify a clinician's identity or instructions.").font(.caption).foregroundStyle(.secondary)
                }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
            }.navigationTitle("Save a reply").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save draft") {
                        if store.mutate({ try HandoffEngine.saveReplyDraft(text, eventAt: eventAt, handoffID: handoff.id, synthetic: synthetic, in: &$0) }) { dismiss() }
                        else { failure = store.error }
                    }.accessibilityIdentifier("handoff-reply-save-draft") }
                }.interactiveDismissDisabled(dirty)
                .confirmationDialog("Discard unsaved reply changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() } }
        }
    }
}
