import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CareCore

struct CaptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let initialMode: CaptureMode
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
    @State private var due: Date?
    @State private var dueTimeKnown = false
    var body: some View {
        NavigationStack {
            Group {
                if let savedID { SourceDetailView(id: savedID).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } } }
                else { form }
            }.careDestinations()
                .navigationTitle(savedID == nil ? "Add care information" : "Saved source").navigationBarTitleDisplayMode(.inline)
                .toolbar { if savedID == nil { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { if !text.isEmpty || imported != nil || recordingSourceID != nil { showCancel = true } else { dismiss() } } } } }
        }
        .interactiveDismissDisabled(processing || recordingSourceID != nil || !text.isEmpty || imported != nil)
        .safeAreaInset(edge: .top) { if recordingActive { Label("Recording session active · microphone may be paused below", systemImage: "record.circle.fill").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(10).background(.red).accessibilityIdentifier("persistent-recording-indicator") } }
        .confirmationDialog("Discard this capture?", isPresented: $showCancel, titleVisibility: .visible) {
            Button("Discard capture", role: .destructive) { fileTask?.cancel(); if let id = recordingSourceID { store.deleteSource(id) }; if let id = stagedSourceID { store.deleteSource(id) }; dismiss() }
            Button("Keep editing", role: .cancel) { }
        } message: { Text("Unsaved text and this recording will be removed. Other saved sources are unaffected.") }
        .fileImporter(isPresented: $showFile, allowedContentTypes: mode == .fhir ? [.json] : [.pdf, .plainText, .json, .image], allowsMultipleSelection: false) { result in
            switch result { case .success(let urls): if let url = urls.first { load(url) }; case .failure(let error): localError = error.localizedDescription }
        }
        .sheet(isPresented: $showCamera) { CameraPicker { data in showCamera = false; if let data { loadPhoto(data) } } }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            fileTask = Task { do { if let data = try await item.loadTransferable(type: Data.self) { loadPhoto(data) } } catch { localError = error.localizedDescription } }
        }
        .task { mode = initialMode; if let url = store.importedURL { store.importedURL = nil; load(url) } }
    }
    private var form: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CaptureMode.allCases) { item in
                            Button { mode = item } label: { VStack(spacing: 7) { Image(systemName: item.symbol).font(.title3); Text(item.rawValue).font(.caption) }.frame(width: 82, height: 60).padding(5).foregroundStyle(mode == item ? .white : Theme.accent).background(mode == item ? Theme.accent : Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain).disabled(recordingSourceID != nil)
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
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take a photo", systemImage: "camera") { showCamera = true } }
                        else { Label("Camera unavailable on this device. Choose a photo instead.", systemImage: "camera.badge.ellipsis").foregroundStyle(.secondary) }
                    }
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo or screenshot", systemImage: "photo.on.rectangle") }
                }
            }
            if mode == .file || mode == .fhir {
                Section {
                    Button(mode == .fhir ? "Choose patient-owned FHIR JSON" : "Choose PDF, image, or text file", systemImage: "folder") { showFile = true }
                    if mode == .fhir { Text("Import a single-patient FHIR R4 export you have permission to use. Unsupported resources are preserved in the original file. Subject and clinical extraction always require review.").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if processing { Section { HStack { ProgressView(); Text("Original saved · extracting text locally…") }; Button("Cancel processing") { fileTask?.cancel(); processing = false; if let id = stagedSourceID { store.cancelAnalysis(id) }; localError = "Text extraction cancelled. The original is saved. Save it now or retry from its source." } } }
            if let imported, !imported.message.isEmpty { Section { Text(imported.message).font(.footnote).foregroundStyle(Theme.warning) } }
            if let localError { Section { Text(localError).foregroundStyle(Theme.warning) } }
            Section("Source context · optional") {
                TextField("Title, e.g. Cardiology recap", text: $title).accessibilityIdentifier("capture-title")
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
            if mode == .manual { manualFields }
            else if mode != .fhir || imported?.kind != .fhir {
                Section(imported == nil ? "What would you like to remember?" : "Editable working text · original file is preserved") {
                    TextEditor(text: $text).frame(minHeight: 180).accessibilityIdentifier("capture-text")
                    PasteButton(payloadType: String.self) { strings in text += (text.isEmpty ? "" : "\n") + strings.joined(separator: "\n") }
                }
            }
            Section {
                Button { save() } label: { Label("Save evidence & review", systemImage: "checkmark.shield").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    .disabled(processing || recordingActive || transcribing || (mode == .manual ? label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imported == nil && recordingSourceID == nil)).accessibilityIdentifier("save-evidence")
                Text("A review confirms what was reported, not medical correctness. Saving a source never changes your care information silently.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var manualFields: some View {
        Section("Structured entry") {
            Picker("Category", selection: $kind) { ForEach(EntityKind.allCases) { Text($0.title).tag($0) } }
            TextField("Item name", text: $label)
            Picker("Reported action", selection: $action) { ForEach(ClaimAction.allCases, id: \.self) { Text($0.displayLabel).tag($0) } }
            TextField("Value or instructions", text: $value, axis: .vertical)
            TextField("Numeric value (optional)", text: $numeric).keyboardType(.decimalPad)
            TextField("Unit (optional)", text: $unit)
            if kind == .appointment { Toggle("Appointment time is known", isOn: $dueTimeKnown) }
            OptionalDateField(title: "Due / appointment date", date: $due, time: kind == .appointment && dueTimeKnown)
        }
    }
    private func load(_ url: URL) {
        processing = true; localError = nil
        fileTask = Task {
            do {
                let original = try DocumentProcessor.readOriginal(url)
                guard let id = try stage(original) else { processing = false; return }
                imported = original
                let result = try await DocumentProcessor.process(original, language:store.state.profile.ocrLanguage); try Task.checkCancellation()
                persistExtraction(result, id: id)
                imported = result; title = result.title; text = result.text; if result.kind == .fhir { mode = .fhir }
            } catch is CancellationError { } catch { localError = error.localizedDescription }
            processing = false
        }
    }
    private func loadPhoto(_ data: Data) {
        guard data.count <= 30_000_000 else { localError = "Choose an image smaller than 30 MB."; return }
        processing = true; localError = nil
        fileTask = Task {
            do {
                let original = ImportedEvidence(data: data, text: "", kind: .photo, pages: [], ext: DocumentProcessor.imageFileExtension(data), title: "Photo or screenshot")
                guard let id = try stage(original) else { processing = false; return }
                imported = original
                let result = (try? await DocumentProcessor.ocr(data, language:store.state.profile.ocrLanguage)) ?? ""
                guard !Task.isCancelled else { processing = false; return }
                var processed = original; processed.text = result; imported = processed; persistExtraction(processed, id: id)
                text = result; if title.isEmpty { title = original.title }; processing = false
                if result.isEmpty { localError = "No readable text found. The photo can still be saved." }
            } catch { localError = error.localizedDescription; processing = false }
        }
    }
    private func stage(_ original: ImportedEvidence) throws -> UUID? {
        let existing = Set(store.state.sources.map(\.id))
        let id = try store.capture(title: original.title, kind: original.kind, text: original.text, data: original.data, extension: original.ext, event: event, encounterID: encounter, provider: provider, analyze: false)
        if existing.contains(id) { savedID = id; return nil }
        if let previous = stagedSourceID { store.deleteSource(previous) }
        stagedSourceID = id
        _ = store.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .processing; state.sources[i].processingMessage = "Original evidence is saved. Local text extraction can be retried if interrupted." } }
        return id
    }
    private func persistExtraction(_ result: ImportedEvidence, id: UUID) {
        _ = store.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].originalText = result.text; state.sources[i].workingText = result.text; state.sources[i].pages = result.pages; state.sources[i].state = .saved; state.sources[i].processingMessage = result.message } }
    }
    private func save() {
        do {
            if let id = stagedSourceID {
                guard let source = store.source(id), store.editSource(id, title: title.isEmpty ? source.title : title, text: text.isEmpty ? source.workingText : text, event: event, encounter: encounter, provider: provider) else { return }
                store.analyze(id); savedID = id; return
            }
            if let id = recordingSourceID {
                guard let source = store.source(id) else { return }
                guard store.editSource(id, title: title.isEmpty ? source.title : title, text: text, event: event, encounter: encounter, provider: provider) else { return }
                if !text.isEmpty { store.analyze(id) }; savedID = id; return
            }
            if let imported, imported.kind == .fhir { savedID = try store.importFHIR(title: title, data: imported.data, event: event, encounter: encounter); return }
            if mode == .manual {
                if !numeric.isEmpty && Double(numeric) == nil { throw CareError.invalid("Enter a valid numeric value, or leave it blank.") }
                let evidence = "\(kind.rawValue): \(label)\nAction: \(action.rawValue)\nValue: \(value) \(numeric) \(unit)" + (due.map { "\nDate: \($0.ISO8601Format())" } ?? "")
                let id = try store.capture(title: title.isEmpty ? label : title, kind: .manual, text: evidence, event: event, encounterID: encounter, provider: provider, analyze: false)
                if !store.state.claims.contains(where: { $0.sourceID == id }) {
                    var c = Claim(sourceID: id, kind: kind, label: label, quote: evidence); c.action = action; c.value = value; c.numericValue = Double(numeric); c.unit = unit; c.eventAt = event; c.dueAt = due; c.duePrecision = due == nil ? .unknown : .exact; c.dueTimeKnown = dueTimeKnown; c.confidence = 1
                    _ = store.mutate { state in state.claims.append(c); if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].state = .needsReview } }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if sourceID == nil {
                if visit { Toggle("Everyone present has agreed to this recording", isOn: $consent); Text("Ask permission before each recording. Follow the rules that apply where you are. No speaker identity is assumed.").font(.caption).foregroundStyle(.secondary) }
                Button(visit ? "Start visit recording" : "Record a quick update", systemImage: "mic.fill") { start() }.disabled(visit && !consent)
            }
            if audio.recording {
                HStack { Image(systemName: "record.circle.fill").foregroundStyle(.red); Text(audio.paused ? "Recording paused" : "Recording · microphone on").font(.headline); Spacer(); Text(Duration.seconds(audio.elapsed).formatted(.time(pattern: .minuteSecond))).monospacedDigit() }.accessibilityIdentifier("recording-indicator")
                HStack { Button(audio.paused ? "Resume" : "Pause") { if audio.paused { audio.resume() } else { audio.pause() } }; Spacer(); Button("Stop & transcribe") { stop() }.buttonStyle(.borderedProminent) }
                Text("Recording pauses when the app leaves the foreground. Keep this screen visible.").font(.caption).foregroundStyle(.secondary)
            }
            if audio.transcribing { ProgressView("Transcribing on this iPhone…"); Button("Cancel transcription") { task?.cancel(); audio.cancelTranscription() } }
            if sourceID != nil && !audio.recording && !audio.transcribing { Text("Audio captured. Edit the transcript below, then save and review.").font(.footnote); if transcript.isEmpty { Button("Retry local transcription") { transcribe() } } }
            if !audio.message.isEmpty { Text(audio.message).font(.footnote).foregroundStyle(Theme.warning) }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.warning) }
        }.onDisappear { audio.stop(); audio.cancelTranscription(); task?.cancel() }
            .onChange(of: scenePhase) { _, phase in if phase != .active && audio.recording { audio.pause() } }
            .onChange(of: audio.recording) { _, value in active = value }
            .onChange(of: audio.transcribing) { _, value in transcribing = value }
    }
    private func start() {
        task = Task {
            do {
                let name = try store.vault.write(Data(), extension: "m4a")
                var source = Source(title: visit ? "Visit recording" : "Voice update", kind: visit ? .visitRecording : .voice, text: "", contentHash: UUID().uuidString)
                source.audioFile = name; source.processingMessage = "Recording draft. Audio is stored locally for recovery."
                guard store.mutate({ $0.sources.append(source); $0.audit.append(Audit(action: visit ? "visit_recording_consent" : "voice_recording_started")) }) else { try? store.vault.remove(name); return }
                sourceID = source.id
                do { try await audio.start(url: store.vault.url(name)) }
                catch { store.deleteSource(source.id); sourceID = nil; throw error }
            } catch { self.error = error.localizedDescription }
        }
    }
    private func stop() { audio.stop(); transcribe() }
    private func transcribe() {
        guard let id = sourceID, let name = store.source(id)?.audioFile else { return }
        task = Task {
            do {
                let result = try await audio.transcribe(store.vault.url(name)); try Task.checkCancellation(); transcript = result
                let saved = store.mutate { state in if let i = state.sources.firstIndex(where: { $0.id == id }) { state.sources[i].originalText = result; state.sources[i].workingText = result; state.sources[i].transcriptSegments = audio.segments; state.sources[i].contentHash = ContentHasher.hash(result); state.sources[i].state = .saved; state.sources[i].processingMessage = "Transcript ready for editing." } }
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
