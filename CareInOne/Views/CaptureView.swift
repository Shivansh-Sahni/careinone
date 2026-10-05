import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CareCore

struct CaptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let initialMode: CaptureMode
    @State private var syntheticImport = false
    @State private var mode: CaptureMode = .text
    @State private var title = ""
    @State private var text = ""
    @State private var event: Date?
    @State private var provider = ""
    @State private var encounter: UUID?
    @State private var imported: ImportedEvidence?
    @State private var photo: PhotosPickerItem?
    @State private var showFile = false
    @State private var showCamera = false
    @State private var processing = false
    @State private var localError: String?
    @State private var savedID: UUID?
    @State private var stagedSourceID: UUID?
    @State private var fileTask: Task<Void, Never>?
    @State private var importRun: UUID?
    @State private var importSourceID: UUID?
    @State private var saving = false
    @State private var replacementFile: URL?
    @State private var replacementPhoto: Data?
    @State private var showReplaceText = false
    @State private var showCancel = false
    @State private var recordingSourceID: UUID?
    @State private var recordingActive = false
    @State private var transcribing = false
    @State private var kind: EntityKind = .appointment
    @State private var label = ""
    @State private var action: ClaimAction = .mentioned
    @State private var numeric = ""
    @State private var unit = ""
    @State private var value = ""
    @State private var route = ""
    @State private var frequency = ""
    @State private var medicationForm = ""
    @State private var effective: Date?
    @State private var due: Date?
    @State private var dueTimeKnown = false
    var body: some View {
        CareNavigationStack {
            Group {
                if let savedID { SourceDetailView(id: savedID).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } } }
                else { form }
            }
                .navigationTitle(savedID == nil ? "Add care information" : "Saved source").navigationBarTitleDisplayMode(.inline)
                .toolbar { if savedID == nil { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { if hasDraft { showCancel = true } else { dismiss() } } } } }
        }
        .interactiveDismissDisabled(savedID == nil && (processing || hasDraft))
        .safeAreaInset(edge: .top) { if recordingActive { Label("Recording session active · microphone may be paused below", systemImage: "record.circle.fill").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(10).background(.red).accessibilityIdentifier("persistent-recording-indicator") } }
        .confirmationDialog("Discard this capture?", isPresented: $showCancel, titleVisibility: .visible) {
            Button("Discard capture", role: .destructive) {
                cancelImport()
                if let id = recordingSourceID, !store.deleteSource(id) { localError = store.error; return }
                if let id = stagedSourceID, !store.deleteSource(id) { localError = store.error; return }
                dismiss()
            }
            Button("Keep editing", role: .cancel) { }
        } message: { Text("Unsaved text and this recording will be removed. Other saved sources are unaffected.") }
        .confirmationDialog("Replace the current working text?", isPresented: $showReplaceText, titleVisibility: .visible) {
            Button("Replace working text") {
                if let url = replacementFile { replacementFile = nil; load(url) }
                else if let data = replacementPhoto { replacementPhoto = nil; loadPhoto(data) }
            }
            Button("Keep current text", role: .cancel) { replacementFile = nil; replacementPhoto = nil }
        } message: { Text("The chosen file will replace this editor's text. Already saved original sources remain available in Sources. Keep editing to save or copy your current text first.") }
        .fileImporter(isPresented: $showFile, allowedContentTypes: mode == .fhir ? [.json] : [.pdf, .plainText, .commaSeparatedText, .json, .image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { requestFile(url) }
            case .failure(let error):
                let native = error as NSError
                if native.domain != NSCocoaErrorDomain || native.code != NSUserCancelledError { localError = error.localizedDescription }
            }
        }
        .sheet(isPresented: $showCamera) { CameraPicker { data in showCamera = false; if let data { requestPhoto(data) } } }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            let run = beginImport()
            fileTask = Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw CareError.invalid("This photo could not be loaded. Choose another photo or try again.") }
                    try Task.checkCancellation(); guard importRun == run else { return }
                    finishImport(run); requestPhoto(data)
                } catch is CancellationError { }
                catch { if importRun == run { localError = error.localizedDescription; finishImport(run) } }
            }
        }
        .task { mode = initialMode; encounter = store.captureEncounterID; store.captureEncounterID = nil; if let url = store.importedURL { store.importedURL = nil; syntheticImport = store.importedSynthetic; store.importedSynthetic = false; load(url) } }
        .onDisappear { cancelImport() }
    }
    private var hasDraft: Bool {
        !text.isEmpty || !title.isEmpty || !label.isEmpty || !value.isEmpty || !numeric.isEmpty || !route.isEmpty || !frequency.isEmpty || !medicationForm.isEmpty || event != nil || effective != nil || due != nil || !provider.isEmpty || imported != nil || recordingSourceID != nil
    }
    private var form: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CaptureMode.allCases) { item in
                            Button { mode = item } label: { VStack(spacing: 7) { Image(systemName: item.symbol).font(.title3); Text(item.rawValue).font(.caption) }.frame(width: 82, height: 60).padding(5).foregroundStyle(mode == item ? .white : Theme.accent).background(mode == item ? Theme.accent : Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).disabled(recordingSourceID != nil || stagedSourceID != nil || processing)
                        }
                    }
                }.listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            if mode == .voice || mode == .recording {
                Section { RecordingCaptureView(visit: mode == .recording, sourceID: $recordingSourceID, transcript: $text, active: $recordingActive, transcribing: $transcribing) }
            }
            if mode == .camera || mode == .photo {
                Section("Image") {
                    if mode == .camera {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take a photo", systemImage: "camera") { showCamera = true }.disabled(processing) }
                        else { Label("Camera unavailable on this device. Choose a photo instead.", systemImage: "camera.badge.ellipsis").foregroundStyle(.secondary) }
                    }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo or screenshot", systemImage: "photo.on.rectangle") }.disabled(processing)
                }
            }
            if mode == .file || mode == .fhir {
                Section {
                    Button(mode == .fhir ? "Choose patient-owned FHIR JSON" : "Choose PDF, image, or text file", systemImage: "folder") { showFile = true }.disabled(processing)
                    if mode == .fhir { Text("Import a single-patient FHIR R4 export you have permission to use. Unsupported resources are preserved in the original file. Subject and clinical extraction always require review.").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if processing { Section { HStack { ProgressView(); Text(importSourceID == nil ? "Loading your chosen evidence…" : "Original saved · extracting text locally…") }; Button("Cancel processing") { let originalWasSaved = importSourceID != nil; cancelImport(); localError = originalWasSaved ? "Text extraction cancelled. The original is saved. Save it now or retry from its source." : "Import cancelled. Your existing text is unchanged." } } }
            if let imported, !imported.message.isEmpty { Section { Text(imported.message).font(.footnote).foregroundStyle(Theme.warning) } }
            if let localError { Section { Text(localError).foregroundStyle(Theme.warning) } }
            Section("Source title · optional") {
                TextField("Title, e.g. Cardiology recap", text: $title).accessibilityIdentifier("capture-title")
            }
            if mode == .manual { manualFields }
            else if mode != .fhir || imported?.kind != .fhir {
                Section(imported == nil ? "What would you like to remember?" : "Editable working text · original file is preserved") {
                    EvidenceTextEditor(text: $text, identifier: "capture-text", placeholder: "Type a care update or paste text from a message or document.")
                        .disabled(processing)
                }
            }
            Section {
                DisclosureGroup("Event date, provider, and encounter") {
                OptionalDateField(title: "Event date", date: $event)
                TextField("Provider or practice", text: $provider)
                Picker("Same encounter", selection: $encounter) {
                    Text("Unassigned").tag(UUID?.none)
                    ForEach(store.state.encounters) { encounter in Text(encounter.title).tag(Optional(encounter.id)) }
                }
                Button("Create encounter from this source") {
                    let new = EncounterRecord(title: title.isEmpty ? "Visit" : title, date: event, provider: provider)
                    if store.mutate({ $0.encounters.append(new) }) { encounter = new.id }
                }
                Text("Capture time is recorded automatically. Leave event date unknown if you do not know when it happened.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Button { save() } label: { Label("Save evidence & review", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    .disabled(saving || processing || recordingActive || transcribing || text.count > CaptureText.maximumCharacters || (mode == .manual ? label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imported == nil && recordingSourceID == nil)).accessibilityIdentifier("save-evidence")
                Text("A review confirms what was reported, not medical correctness. Saving a source never changes your care information silently.").font(.caption).foregroundStyle(.secondary)
            }
        }.scrollDismissesKeyboard(.interactively)
    }
    private var manualFields: some View {
        Section("Structured entry") {
            Picker("Category", selection: $kind) { ForEach(EntityKind.allCases) { Text($0.title).tag($0) } }
            TextField("Item name", text: $label)
            Picker("Reported action", selection: $action) { ForEach(ClaimAction.allCases, id: \.self) { Text($0.displayLabel).tag($0) } }
            TextField("Value or instructions", text: $value, axis: .vertical)
            TextField("Numeric value (optional)", text: $numeric).keyboardType(.decimalPad)
            TextField("Unit (optional)", text: $unit)
            if kind == .medication {
                TextField("Route, e.g. oral", text: $route)
                TextField("Frequency, e.g. once daily", text: $frequency)
                TextField("Form, e.g. extended-release tablet", text: $medicationForm)
            }
            OptionalDateField(title: "Effective date", date: $effective)
            if kind == .appointment { Toggle("Appointment time is known", isOn: $dueTimeKnown) }
            OptionalDateField(title: "Due / appointment date", date: $due, time: kind == .appointment && dueTimeKnown)
        }
    }
    private func load(_ url: URL) {
        let run = beginImport()
        fileTask = Task {
            do {
                let original = try await Task.detached(priority: .userInitiated) { try DocumentProcessor.readOriginal(url) }.value
                try Task.checkCancellation(); guard importRun == run else { return }
                guard let id = try stage(original) else { finishImport(run); return }
                imported = original; text = original.text; if title.isEmpty { title = original.title }
                let result = try await DocumentProcessor.process(original, language:store.state.profile.ocrLanguage); try Task.checkCancellation()
                guard importRun == run else { return }
                guard persistExtraction(result, id: id) else { finishImport(run); return }
                imported = result; if title.isEmpty { title = result.title }; text = result.text; if result.kind == .fhir { mode = .fhir }
            } catch is CancellationError { }
            catch { if importRun == run { localError = error.localizedDescription; if let id = importSourceID { store.cancelAnalysis(id) } } }
            finishImport(run)
        }
    }
    private func requestFile(_ url: URL) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { replacementPhoto = nil; replacementFile = url; showReplaceText = true }
        else { load(url) }
    }
    private func requestPhoto(_ data: Data) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { replacementFile = nil; replacementPhoto = data; showReplaceText = true }
        else { loadPhoto(data) }
    }
    private func loadPhoto(_ data: Data) {
        guard data.count <= 30_000_000 else { cancelImport(); localError = "Choose an image smaller than 30 MB."; return }
        let run = beginImport()
        fileTask = Task {
            do {
                let original = ImportedEvidence(data: data, text: "", kind: .photo, pages: [], ext: DocumentProcessor.imageFileExtension(data), title: "Photo or screenshot")
                guard let id = try stage(original) else { finishImport(run); return }
                imported = original; text = ""; if title.isEmpty { title = original.title }
                let processed = try await DocumentProcessor.process(original, language:store.state.profile.ocrLanguage)
                try Task.checkCancellation(); guard importRun == run else { return }
                guard persistExtraction(processed, id: id) else { finishImport(run); return }
                imported = processed; text = processed.text
            } catch is CancellationError { }
            catch { if importRun == run { localError = error.localizedDescription; if let id = importSourceID { store.cancelAnalysis(id) } } }
            finishImport(run)
        }
    }
    private func beginImport() -> UUID {
        cancelImport()
        let run = UUID(); importRun = run; importSourceID = nil; processing = true; localError = nil
        return run
    }
    private func finishImport(_ run: UUID) {
        guard importRun == run else { return }
        importRun = nil; importSourceID = nil; processing = false; fileTask = nil
    }
    private func cancelImport() {
        let wasProcessing = processing
        importRun = nil; fileTask?.cancel(); fileTask = nil; processing = false
        if wasProcessing, let id = importSourceID { store.cancelAnalysis(id) }
        importSourceID = nil
    }
    private func stage(_ original: ImportedEvidence) throws -> UUID? {
        let existing = Set(store.state.sources.map(\.id))
        let id = try store.capture(title: original.title, kind: original.kind, text: original.text, data: original.data, extension: original.ext, event: event, encounterID: encounter, provider: provider, analyze: false)
        if existing.contains(id) { savedID = id; return nil }
        // Choosing another file must not silently delete an original that was already saved.
        if stagedSourceID != nil { store.notice = "Your previous original remains available in Sources." }
        stagedSourceID = id
        importSourceID = id
        guard store.mutate({ state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].synthetic = syntheticImport || store.isDemoWorkspace; state.sources[i].state = .processing; state.sources[i].processingMessage = "Original evidence is saved. Local text extraction can be retried if interrupted." } }) else { throw CareError.invalid("The original was saved, but import progress could not be saved. Open it in Sources to retry.") }
        return id
    }
    @discardableResult private func persistExtraction(_ result: ImportedEvidence, id: UUID) -> Bool {
        let saved = store.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].originalText = result.text; state.sources[i].workingText = result.text; state.sources[i].pages = result.pages; state.sources[i].state = .saved; state.sources[i].processingMessage = result.message } }
        if !saved { localError = store.error ?? "Text extraction could not be saved. The original remains available in Sources." }
        return saved
    }
    private func save() {
        guard !saving, savedID == nil, !processing, !recordingActive, !transcribing else { return }
        saving = true; defer { saving = false }
        do {
            try CaptureText.validate(text)
            if let id = stagedSourceID {
                guard let source = store.source(id), store.editSource(id, title: title.isEmpty ? source.title : title, text: source.kind == .fhir ? source.workingText : text, event: event, encounter: encounter, provider: provider) else { localError = store.error ?? "This source could not be saved. Your draft remains here."; return }
                if source.kind == .fhir || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { store.analyze(id) }
                savedID = id; return
            }
            if let id = recordingSourceID {
                guard let source = store.source(id) else { localError = "This recording source is no longer available. Copy your draft before choosing another capture."; return }
                guard store.editSource(id, title: title.isEmpty ? source.title : title, text: text, event: event, encounter: encounter, provider: provider) else { localError = store.error ?? "This recording could not be saved. Your draft remains here."; return }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { store.analyze(id) }; savedID = id; return
            }
            if let imported, imported.kind == .fhir { savedID = try store.importFHIR(title: title, data: imported.data, event: event, encounter: encounter); return }
            if mode == .manual {
                if !numeric.isEmpty && (Double(numeric)?.isFinite != true) { throw CareError.invalid("Enter a valid numeric value, or leave it blank.") }
                let evidence = "\(kind.rawValue): \(label)\nAction: \(action.rawValue)\nValue: \(value) \(numeric) \(unit)" + (kind == .medication ? "\nRoute: \(route)\nFrequency: \(frequency)\nForm: \(medicationForm)" : "") + (effective.map { "\nEffective: \($0.ISO8601Format())" } ?? "") + (due.map { "\nDate: \($0.ISO8601Format())" } ?? "")
                let id = try store.capture(title: title.isEmpty ? label : title, kind: .manual, text: evidence, event: event, encounterID: encounter, provider: provider, analyze: false)
                if !store.state.claims.contains(where: { $0.sourceID == id }) {
                    var c = Claim(sourceID: id, kind: kind, label: label, quote: evidence); c.action = action; c.value = value; c.numericValue = Double(numeric); c.unit = unit; c.eventAt = event; c.effectiveAt = effective; c.route = route; c.frequency = frequency; c.form = medicationForm; c.dueAt = due; c.duePrecision = due == nil ? .unknown : .exact; c.dueTimeKnown = dueTimeKnown; c.confidence = 1
                    guard store.mutate({ state in state.claims.append(c); if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .needsReview } }) else { return }
                }
                savedID = id; return
            }
            let evidence = imported?.text ?? text
            let previousIDs = Set(store.state.sources.map(\.id))
            let id = try store.capture(title: title, kind: imported?.kind ?? .typed, text: evidence, data: imported?.data, extension: imported?.ext ?? "txt", event: event, encounterID: encounter, provider: provider, pages: imported?.pages ?? [], analyze: false)
            if previousIDs.contains(id) { savedID = id; return }
            if text != evidence { store.editSource(id, title: title, text: text, event: event, encounter: encounter, provider: provider) }
            store.analyze(id); savedID = id
        } catch { localError = error.localizedDescription }
    }
}

/// The same editor is used for new sources and corrections, including system-authorized paste.
struct EvidenceTextEditor: View {
    @Binding var text: String
    let identifier: String
    let placeholder: String
    var minimumHeight: CGFloat = 180
    var maximumCharacters: Int = CaptureText.maximumCharacters
    var accessibilityName = "Source text"
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focused: Bool
    @State private var pasteError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))) {
                // iOS 18 delivers transferred paste values on a background executor.
                // Keep the callback nonisolated and update the editor on the main actor.
                PasteButton(payloadType: String.self) { @Sendable strings in
                    Task { @MainActor in
                        do { text = try CaptureText.appendingPaste(strings, to: text, limit: maximumCharacters); pasteError = nil }
                        catch { pasteError = error.localizedDescription }
                    }
                }.labelStyle(.titleAndIcon).controlSize(.regular)
                    .accessibilityLabel("Paste text").accessibilityIdentifier(identifier + "-paste")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(text.count.formatted()) characters").font(.caption).monospacedDigit()
                    .foregroundStyle(text.count > maximumCharacters ? Theme.warning : Color.secondary)
            }
            TextEditor(text: $text).frame(minHeight: minimumHeight).focused($focused)
                .accessibilityIdentifier(identifier).accessibilityLabel(accessibilityName)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty { Text(placeholder).foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 4).allowsHitTesting(false).accessibilityHidden(true) }
                }
            if let pasteError { Text(pasteError).font(.caption).foregroundStyle(Theme.warning) }
            if text.count > maximumCharacters { Text("Shorten this text to \(maximumCharacters.formatted()) characters or fewer before saving. Your current text remains available to copy or edit.").font(.caption).foregroundStyle(Theme.warning) }
        }.toolbar {
            if focused { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing text") { focused = false }.accessibilityIdentifier(identifier + "-done") } }
        }
    }
}

struct RecordingCaptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let visit: Bool
    @Binding var sourceID: UUID?
    @Binding var transcript: String
    @Binding var active: Bool
    @Binding var transcribing: Bool
    @State private var consent = false
    @State private var audio = AudioCapture()
    @State private var task: Task<Void, Never>?
    @State private var error: String?
    @State private var starting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sourceID == nil {
                if visit { Toggle("Everyone present has agreed to this recording", isOn: $consent); Text("Ask permission before each recording. Follow the rules that apply where you are. No speaker identity is assumed.").font(.caption).foregroundStyle(.secondary) }
                Button(visit ? "Start visit recording" : "Record a quick update", systemImage: "mic.fill") { start() }.disabled(starting || (visit && !consent))
                if starting { ProgressView("Preparing the microphone…") }
            }
            if audio.recording {
                HStack { Image(systemName: "record.circle.fill").foregroundStyle(.red); Text(audio.paused ? "Recording paused" : "Recording · microphone on").font(.headline); Spacer(); Text(Duration.seconds(audio.elapsed).formatted(.time(pattern: .minuteSecond))).monospacedDigit() }.accessibilityIdentifier("recording-indicator")
                HStack { Button(audio.paused ? "Resume" : "Pause") { if audio.paused { audio.resume() } else { audio.pause() } }; Spacer(); Button("Stop & transcribe") { stop() }.buttonStyle(.borderedProminent) }
                Text("Recording pauses when the app leaves the foreground. Keep this screen visible.").font(.caption).foregroundStyle(.secondary)
            }
            if audio.transcribing { ProgressView("Transcribing on this device…"); Button("Cancel transcription") { task?.cancel(); audio.cancelTranscription() } }
            if sourceID != nil && !audio.recording && !audio.transcribing { Text("Audio captured. Edit the transcript below, then save and review.").font(.footnote); if transcript.isEmpty { Button("Retry local transcription") { transcribe() } } }
            if !audio.message.isEmpty { Text(audio.message).font(.footnote).foregroundStyle(Theme.warning) }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.warning) }
        }.onDisappear { audio.stop(); audio.cancelTranscription(); task?.cancel() }
            .onChange(of: scenePhase) { _, phase in if phase != .active && audio.recording { audio.pause() } }
            .onChange(of: audio.recording) { _, value in active = value }
            .onChange(of: audio.transcribing) { _, value in transcribing = value }
    }
    private func start() {
        guard !starting, sourceID == nil else { return }
        starting = true; active = true; error = nil
        task = Task {
            defer { starting = false; active = audio.recording }
            do {
                try Task.checkCancellation()
                let name = try store.vault.write(Data(), extension: "m4a")
                var source = Source(title: visit ? "Visit recording" : "Voice update", kind: visit ? .visitRecording : .voice, text: "", contentHash: UUID().uuidString)
                source.audioFile = name; source.processingMessage = "Recording draft. Audio is stored locally for recovery."
                guard store.mutate({ $0.sources.append(source); $0.audit.append(Audit(action: visit ? "visit_recording_consent" : "voice_recording_started")) }) else { try? store.vault.remove(name); self.error = store.error ?? "Recording could not be prepared for saving. Try again when storage is available."; return }
                sourceID = source.id
                do { try await audio.start(url: store.vault.url(name)) }
                catch {
                    if store.deleteSource(source.id) { sourceID = nil }
                    else { throw CareError.invalid("The microphone did not start, and its empty draft could not be removed. Retry saving or discard this capture when storage is available. " + error.localizedDescription) }
                    throw error
                }
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
    private func stop() { audio.stop(); transcribe() }
    private func transcribe() {
        guard !transcribing, let id = sourceID, let name = store.source(id)?.audioFile else { return }
        transcribing = true; error = nil
        task = Task {
            defer { transcribing = false }
            do {
                let result = try await audio.transcribe(store.vault.url(name)); try Task.checkCancellation(); transcript = result
                let saved = store.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].originalText = result; state.sources[i].workingText = result; state.sources[i].transcriptSegments = audio.segments; state.sources[i].contentHash = ContentHasher.hash(result); state.sources[i].state = .saved; state.sources[i].processingMessage = result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No speech text was recognized. The recording remains saved; retry transcription or type a recap." : "Transcript ready for editing." } }
                if !saved { self.error = store.error ?? "The transcript could not be saved. Your editable text remains below and the original recording is preserved; retry saving." }
                if saved && !result.isEmpty && !store.state.profile.retainAudio { store.deleteAudio(id) }
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (Data?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController { let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.92)) }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    }
}
