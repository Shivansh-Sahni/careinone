import SwiftUI
import CareCore

/// Uses the same importer and review gate as patient-owned files.
struct SampleEvidenceView: View {
    @Environment(AppStore.self) private var store
    @State private var files: [URL] = []
    @State private var failure: String?
    var body: some View {
        List {
            Section {
                Text("Try the complete import → review → My Care workflow with fictional records. Nothing is accepted automatically. These samples are labeled synthetic and can be removed in Settings.")
            }
            ForEach(files, id: \.self) { url in
                Section(url.deletingPathExtension().lastPathComponent) {
                    Button("Import and review", systemImage: "square.and.arrow.down") {
                        loadSamplesIfNeeded()
                        guard let readable = files.first(where: { $0.lastPathComponent == url.lastPathComponent }), FileManager.default.isReadableFile(atPath: readable.path) else {
                            failure = "This practice file is unavailable. Reload the samples and try again."; return
                        }
                        store.importedURL = readable
                        store.importedSynthetic = true
                        store.openAdd(.file)
                    }.accessibilityIdentifier("practice-import-" + (url.pathExtension == "json" ? "fhir" : url.pathExtension))
                    if FileManager.default.isReadableFile(atPath: url.path) { ShareLink("Save sample to Files", item: url) }
                }
            }
            if let failure {
                Section {
                    Text(failure).foregroundStyle(Theme.warning)
                    Button("Reload practice files") { loadSamplesIfNeeded() }.accessibilityIdentifier("practice-reload")
                }
            }
            Section("Try a new patient") {
                Text("To start from scratch, create an encrypted backup in Settings first if you want to keep the current records. Then use Delete all local data. The short welcome screen will appear again. You can always load the synthetic demo later.")
            }
        }
        .navigationTitle("Practice imports")
        .task { loadSamplesIfNeeded() }
        .onChange(of: store.state) { _, _ in loadSamplesIfNeeded() }
    }
    private func loadSamplesIfNeeded() {
        guard files.count != 4 || !files.allSatisfy({ FileManager.default.isReadableFile(atPath: $0.path) }) else { failure = nil; return }
        files = []; failure = nil
        do { files = try ExportService.practiceFiles() }
        catch { failure = error.localizedDescription }
    }
}
