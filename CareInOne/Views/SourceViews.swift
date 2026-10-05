import SwiftUI
import QuickLook
import PDFKit
import CareCore

struct SourcesView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    private var sources: [Source] { store.state.sources.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.workingText.localizedCaseInsensitiveContains(search) || $0.originalText.localizedCaseInsensitiveContains(search) || $0.provider.localizedCaseInsensitiveContains(search) }.sorted { $0.capturedAt > $1.capturedAt } }
    var body: some View {
        List {
            Section { Text("Original evidence stays with you, even when analysis is unavailable.").font(.subheadline).foregroundStyle(.secondary) }
            if sources.isEmpty {
                if search.isEmpty { ContentUnavailableView("Start with one source", systemImage: "tray", description: Text("Add a note, voice update, photo, or document.")) }
                else { ContentUnavailableView.search(text: search) }
            }
            ForEach(sources) { source in
                NavigationLink(value: Route.source(source.id)) { SourceRow(source: source) }
            }
        }.navigationTitle("Sources").searchable(text: $search, prompt: "Search original sources")
    }
}
struct SourceRow: View {
    let source: Source
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: source.kind == .voice || source.kind == .visitRecording ? "waveform" : source.kind == .photo ? "photo" : "doc.text").font(.title3).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(source.title).font(.headline)
                Text(source.kind.displayLabel + " · " + (source.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Event date unknown")).font(.caption).foregroundStyle(.secondary)
                if [.needsReview, .pending, .processing, .failed, .cancelled].contains(source.state) { Badge(text: source.state.displayLabel, caution: source.state == .failed) }
            }
        }.padding(.vertical, 5)
    }
}
struct SourceDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var reviewClaim: Claim?
    @State private var edit = false
    @State private var delete = false
    @State private var deleteAudio = false
    @State private var textExport: URL?
    @State private var file: PreviewFile?
    @State private var playback = AudioPlayback()
    @State private var transcription = AudioCapture()
    @State private var startingTranscription = false
    private var source: Source? { store.source(id) }
    private var pending: [Claim] { store.state.claims.filter { $0.sourceID == id && $0.review == .pending } }
    var body: some View {
        Group {
            if let source {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        CareCard {
                            Text(source.title).font(.title2.bold())
                            HStack { Badge(text: source.kind.displayLabel); if source.synthetic { Badge(text: "Synthetic demo") }; Badge(text: "Version \(source.version)") }
                            metadata("Captured", source.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            metadata("Event", source.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                            if !source.provider.isEmpty { metadata("Provider", source.provider) }
                            if let encounter = store.state.encounters.first(where: { $0.id == source.encounterID }) { NavigationLink(value: Route.prepare(encounter.id)) { Label(encounter.title, systemImage: "calendar") } }
                            Button("Edit title, date, or working text", systemImage: "pencil") { edit = true }
                            NavigationLink(value: Route.evidenceMap(.source(id))) { Label("What this source informs", systemImage: "point.3.connected.trianglepath.dotted") }
                            if let name = source.originalFile { Button("Open original file", systemImage: "doc.viewfinder") { do { file = PreviewFile(url: try store.vault.url(name)) } catch { store.error = error.localizedDescription } } }
                            if let name = source.originalFile, let url = try? store.vault.url(name) {
                                ShareLink("Export original file", item: url)
                            }
                            if !source.originalText.isEmpty {
                                Button("Prepare original text export", systemImage: "square.and.arrow.up") {
                                    textExport = nil; store.error = nil
                                    do { textExport = try ExportService.sourceText(source) } catch { store.error = error.localizedDescription }
                                }
                                if let textExport, FileManager.default.isReadableFile(atPath: textExport.path) { ShareLink("Save or share original text", item: textExport) }
                            }
                            if let name = source.audioFile {
                                Button(playback.playing ? "Stop audio" : "Play saved audio", systemImage: playback.playing ? "stop.fill" : "play.fill") { Task { do { try await playback.toggle(store.vault.url(name)) } catch is CancellationError { } catch { if store.source(id) != nil { store.error = error.localizedDescription } } } }
                                if let url = try? store.vault.url(name) { ShareLink("Export saved audio", item: url) }
                                Button("Delete audio only", role: .destructive) { deleteAudio = true }
                                if source.workingText.isEmpty {
                                    Button("Retry on-device transcription") {
                                        guard !startingTranscription else { return }
                                        startingTranscription = true
                                        Task {
                                            defer { startingTranscription = false }
                                            do { let text = try await transcription.transcribe(store.vault.url(name)); if store.saveRecoveredTranscript(id, text: text, segments: transcription.segments), !text.isEmpty, !store.state.profile.retainAudio { store.deleteAudio(id) } }
                                            catch is CancellationError { }
                                            catch { store.error = error.localizedDescription }
                                        }
                                    }.disabled(startingTranscription || transcription.transcribing)
                                    if transcription.transcribing { ProgressView("Transcribing…"); Button("Cancel transcription") { transcription.cancelTranscription() } }
                                }
                            }
                        }
                        if source.state == .processing && store.analysisInProgress(id) {
                            CareCard { ProgressView(source.processingMessage); Button("Cancel analysis") { store.cancelAnalysis(id) } }
                        } else {
                            CareCard {
                                if source.state == .processing { Text("Processing is no longer running, or its result could not be saved. Your original evidence is preserved. Retry extraction or analysis to finish.").font(.subheadline).foregroundStyle(Theme.warning) }
                                Text(SourceReviewStatus(source: source, claims: store.state.claims).message)
                                    .font(.subheadline).accessibilityIdentifier("source-review-status")
                                if source.workingText.isEmpty && source.originalFile != nil && source.kind != .fhir { Button("Retry text extraction from original") { store.extractOriginal(id) } }
                                if !source.workingText.isEmpty || source.kind == .fhir {
                                    HStack { Button(source.state == .failed ? "Retry analysis" : "Re-analyze") { store.analyze(id, force: true) }; Spacer(); Button("Use local analysis") { store.analyze(id, force: true, localOnly: true) } }.font(.subheadline)
                                }
                                if !source.workingText.isEmpty { Button("Add a structured claim from this source", systemImage: "plus") { reviewClaim = Claim(sourceID: id, kind: .other, label: "", quote: String(source.workingText.prefix(6000))) } }
                            }
                        }
                        if !pending.isEmpty {
                            SectionHeading(title: "Review what was reported", subtitle: "Confirming an extraction does not verify medical correctness.")
                            let clarifications = ProposalValidator.clarifications(pending)
                            if !clarifications.isEmpty { CareCard { Text("A few things to check").font(.headline); ForEach(clarifications, id: \.self) { Text("• " + $0).font(.subheadline) } } }
                            let safe = pending.filter { !$0.needsStrongReview }
                            if !safe.isEmpty { Button("Accept \(safe.count) low-risk, high-confidence items") { _ = store.accept(safe) }.buttonStyle(.bordered) }
                            ForEach(pending) { claim in
                                CareCard {
                                    ClaimSummary(claim: claim)
                                    Text("“\(claim.quote)”").font(.subheadline).foregroundStyle(.secondary).lineLimit(6)
                                    if let page = claim.page { Text("PDF page \(page)").font(.caption).foregroundStyle(.secondary) }
                                    if claim.needsStrongReview { Label("Individual review required", systemImage: "eye").font(.caption).foregroundStyle(Theme.warning) }
                                    HStack { Button("Review & edit") { reviewClaim = claim }.buttonStyle(.borderedProminent); Spacer(); Button("Reject", role: .destructive) { store.reject(claim) } }
                                }
                            }
                        }
                        let accepted = store.state.claims.filter { $0.sourceID == id && $0.canonical }
                        if !accepted.isEmpty {
                            SectionHeading(title: "Added to My Care")
                            ForEach(accepted) { claim in
                                CareCard {
                                    ClaimSummary(claim: claim)
                                    Text("“\(claim.quote)”").font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                                    if let entity = claim.entityID { NavigationLink("View item & history", value: Route.entity(entity)) }
                                    Button("Correct this saved report", systemImage: "pencil") { reviewClaim = claim }
                                        .accessibilityIdentifier("correct-claim-" + claim.id.uuidString)
                                }
                            }
                        }
                        CareCard {
                            DisclosureGroup("Working text") { Text(source.workingText.isEmpty ? "No text has been added." : source.workingText).font(.subheadline).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            DisclosureGroup("Original captured text") { Text(source.originalText.isEmpty ? "Original evidence is in the attached file or audio." : source.originalText).font(.subheadline).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            if !source.previousText.isEmpty { DisclosureGroup("Earlier working versions (\(source.previousText.count))") { ForEach(Array(source.previousText.enumerated()), id: \.offset) { index, text in Text("Version \(index + 1)\n" + text).font(.caption).padding(.vertical, 5) } } }
                            let rejected = store.state.claims.filter { $0.sourceID == id && $0.review == .rejected }
                            if !rejected.isEmpty {
                                DisclosureGroup("Earlier or withdrawn reports (\(rejected.count))") {
                                    ForEach(rejected) { claim in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(claim.summary + " · not in My Care").font(.caption)
                                            Button("Review this report again") { reviewClaim = claim }
                                        }
                                    }
                                }
                            }
                        }
                        Button("Delete source and its claims", role: .destructive) { delete = true }.frame(maxWidth: .infinity).padding(.bottom)
                    }.padding(20)
                }.background(Theme.background)
            } else { ContentUnavailableView("Source removed", systemImage: "doc.badge.minus") }
        }.navigationTitle("Source evidence").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $reviewClaim) { ReviewEditor(claim: $0) }
            .sheet(isPresented: $edit) { if let source { SourceEditView(source: source) } }
            .sheet(item: $file) { QuickLookView(url: $0.url) }
            .sheet(isPresented: $delete) { EvidenceImpactView(deletingSourceID: id) { dismiss() } }
            .confirmationDialog("Delete audio only?", isPresented: $deleteAudio, titleVisibility: .visible) { Button("Delete audio", role: .destructive) { playback.stop(); store.deleteAudio(id) } } message: { Text("The transcript, source, and reviewed claims remain saved.") }
            .onChange(of: store.state) {
                textExport = nil
                if source == nil { file = nil; playback.stop(); transcription.cancelTranscription() }
            }
            .onChange(of: source?.originalFile) { file = nil }
            .onAppear { if let textExport, !FileManager.default.isReadableFile(atPath: textExport.path) { self.textExport = nil } }
            .onDisappear { playback.stop(); transcription.cancelTranscription() }
    }
    private func metadata(_ name: String, _ value: String) -> some View { HStack(alignment: .top) { Text(name).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.caption) }
}
struct SourceEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let source: Source
    @State private var title: String; @State private var text: String; @State private var event: Date?; @State private var encounter: UUID?; @State private var provider: String
    @State private var showDiscard = false
    @State private var saveError: String?
    private var changed: Bool { title != source.title || text != source.workingText || event != source.eventAt || encounter != source.encounterID || provider != source.provider }
    init(source: Source) { self.source = source; _title = State(initialValue: source.title); _text = State(initialValue: source.workingText); _event = State(initialValue: source.eventAt); _encounter = State(initialValue: source.encounterID); _provider = State(initialValue: source.provider) }
    var body: some View {
        NavigationStack { Form {
            TextField("Title", text: $title); OptionalDateField(title: "Event date", date: $event); TextField("Provider", text: $provider)
            Picker("Encounter", selection: $encounter) { Text("Unassigned").tag(UUID?.none); ForEach(store.state.encounters) { Text($0.title).tag(Optional($0.id)) } }
            Section("Working text") {
                if source.kind == .fhir { Text("FHIR working text is generated from the preserved JSON. Use Re-analyze on the source to refresh it.").font(.caption).foregroundStyle(.secondary); Text(text).textSelection(.enabled) }
                else { EvidenceTextEditor(text: $text, identifier: "source-edit-text", placeholder: "Add or correct the working text. The original remains preserved.", minimumHeight: 250) }
            }
            if let saveError { Text(saveError).foregroundStyle(Theme.warning) }
            Text("Changing working text or event date retires existing proposals and claims from this source until they are reviewed again. The original evidence and earlier versions remain preserved.").font(.caption).foregroundStyle(.secondary)
        }.scrollDismissesKeyboard(.interactively).navigationTitle("Edit source").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if changed { showDiscard = true } else { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try CaptureText.validate(text)
                        if store.editSource(source.id, title: title.trimmingCharacters(in: .whitespacesAndNewlines), text: text, event: event, encounter: encounter, provider: provider) { dismiss() }
                        else { saveError = store.error ?? "This change could not be saved. Your edits remain here." }
                    } catch { saveError = error.localizedDescription }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > CaptureText.maximumCharacters)
            }
        } }.interactiveDismissDisabled(changed)
            .confirmationDialog("Discard these source edits?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Discard edits", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("The previously saved source and its original evidence remain unchanged.") }
    }
}
struct PreviewFile: Identifiable { let id = UUID(); let url: URL }
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController { let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) { }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL; init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}
