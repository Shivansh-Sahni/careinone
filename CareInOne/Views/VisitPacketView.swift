import SwiftUI
import CareCore

struct VisitPacketView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    var encounterID: UUID? = nil
    var initialSelection: Set<String>? = nil
    @State private var options = PacketOptions()
    @State private var since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var filterRecentChanges = true
    @State private var initialized = false
    @State private var priority = ""
    @State private var preview: PacketPreview?
    @State private var tracking = false
    private var items: [PacketItem] { VisitPacketBuilder.items(store.state, encounterID: encounterID, since: filterRecentChanges ? since : nil) }
    private var visibleOptions: PacketOptions {
        var value = options; value.selectedIDs.formIntersection(Set(items.map(\.id))); return value
    }
    var body: some View {
        List {
            Section {
                Text("Choose what you want to carry into this visit or share with someone helping you.")
                Text("Care items include supporting quotes, and medication and allergy items keep differing reports together. Personal notes and profile fields start unselected. Quotes can still contain identifying details; review the copy before sharing.").font(.caption).foregroundStyle(.secondary)
                Button("Preview selected packet", systemImage: "doc.text.magnifyingglass") {
                    preview = PacketPreview(text: VisitPacketBuilder.text(store.state, items: items, options: options), editable: options.asMessage)
                }.disabled(!items.contains { options.selectedIDs.contains($0.id) }).accessibilityIdentifier("packet-preview")
                Button("Track selected handoff", systemImage: "arrow.up.doc.on.clipboard") { tracking = true }.disabled(visibleOptions.selectedIDs.isEmpty).accessibilityIdentifier("packet-track")
                Text("\(items.filter { options.selectedIDs.contains($0.id) }.count) items selected").font(.caption)
            }
            Section("What matters to you") {
                TextField("A question or priority for this visit", text: $priority, axis: .vertical).accessibilityIdentifier("packet-priority")
                Button("Save to my visit questions") {
                    if store.addQuestion(priority, encounter: encounterID) {
                        let saved = store.state.questions.first { !$0.answered && $0.entityID == nil && $0.encounterID == encounterID && Normalizer.key($0.text) == Normalizer.key(priority) }
                        if let saved { options.selectedIDs.insert("question:" + saved.id.uuidString) }
                        priority = ""
                    }
                }.disabled(priority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Sharing choices") {
                Toggle("Format as a message to my care team", isOn: $options.asMessage)
                Toggle("Include my name", isOn: $options.includeName)
                Toggle("Include my date of birth", isOn: $options.includeBirthDate)
                Toggle("Include my local contact", isOn: $options.includeContact)
                Button("Select suggested items") { options.selectedIDs = VisitPacketBuilder.suggestedSelection(items) }
                Button("Clear selection") { options.selectedIDs.removeAll() }.accessibilityIdentifier("packet-clear")
            }
            Section("Time range for changes") {
                Toggle("Limit recent changes", isOn: $filterRecentChanges)
                if filterRecentChanges { DatePicker("Saved since", selection: $since, displayedComponents: .date) }
                Text("This filters when changes were saved in the app. Earlier unresolved work remains available regardless of appointment date.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(PacketSection.allCases, id: \.self) { section in
                let group = items.filter { $0.section == section }
                if !group.isEmpty {
                    Section(section.rawValue) {
                        ForEach(group) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(item.title, isOn: Binding(get: { options.selectedIDs.contains(item.id) }, set: { include in
                                    if include { options.selectedIDs.insert(item.id) } else { options.selectedIDs.remove(item.id) }
                                })).accessibilityIdentifier("packet-item-" + item.id)
                                DisclosureGroup("Review included details") { Text(item.detail).font(.caption).textSelection(.enabled) }
                                ForEach(item.sourceIDs, id: \.self) { SourceLink(id: $0) }
                            }
                        }
                    }
                }
            }
            if items.isEmpty { Text("No reviewed care or questions have been saved yet. Add a question above or capture an update.") }
        }.navigationTitle("Visit packet").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !initialized else { return }
                options.encounterID = encounterID
                options.selectedIDs = initialSelection.map { $0.intersection(Set(items.map(\.id))) } ?? VisitPacketBuilder.suggestedSelection(items)
                initialized = true
            }
            .sheet(item: $preview) { PacketPreviewView(snapshot: $0.text, editable: $0.editable) }
            .sheet(isPresented: $tracking) { HandoffCreateView(options: visibleOptions) { navigate(.handoff($0)) } }
    }
}
private struct PacketPreview: Identifiable { let id = UUID(); let text: String; let editable: Bool }
private struct PacketPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    let editable: Bool
    init(snapshot: String, editable: Bool) { _draft = State(initialValue: snapshot); self.editable = editable }
    @State private var pdf: PreparedTextExport?
    @State private var failure: String?
    @FocusState private var editing: Bool
    private var empty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Review the complete copy below. Sharing sends only this snapshot; it does not grant access to your app.").font(.subheadline)
                    ShareLink("Share selected text", item: draft).disabled(empty)
                    Button("Create selected PDF") {
                        editing = false; pdf?.discard(); pdf = nil; failure = nil
                        do { pdf = try ExportService.preparedPDF(draft, name: "CareInOne-visit-packet.pdf") }
                        catch { failure = error.localizedDescription }
                    }.disabled(empty).accessibilityIdentifier("packet-pdf")
                    if let pdf, pdf.isAvailable(for: draft) { ShareLink("Share selected PDF", item: pdf.url) }
                    if let failure { Text(failure).foregroundStyle(.red) }
                    if editable {
                        Text("Edit this outgoing draft as needed. Your saved sources and care memory stay unchanged.").font(.caption)
                        TextEditor(text: $draft).focused($editing).frame(minHeight: 450).accessibilityLabel("Outgoing message").accessibilityIdentifier("packet-message-text")
                    } else {
                        Text(draft).font(.subheadline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("packet-preview-text")
                    }
                }.padding()
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Review before sharing").onChange(of: draft) { _, _ in pdf?.discard(); pdf = nil; failure = nil }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { editing = false; dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing") { editing = false } }
                }
        }
    }
}
