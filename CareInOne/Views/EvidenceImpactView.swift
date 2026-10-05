import SwiftUI
import CareCore

struct EvidenceImpactView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var claims: [Claim] = []
    var deletingSourceID: UUID? = nil
    var onDeleted: () -> Void = {}
    @State private var confirmDelete = false
    private var result: Result<ContinuityComparison, Error> {
        Result {
            if let deletingSourceID { return try EvidenceImpact.deleting(deletingSourceID, in: store.state) }
            return try EvidenceImpact.accepting(claims, in: store.state)
        }
    }
    var body: some View {
        CareNavigationStack {
            List {
                Section {
                    Text(deletingSourceID == nil ? "If you accept this reviewed claim" : "Before you delete this source").font(.title2.bold())
                    Text("See how your saved care would change. Nothing is saved or deleted by opening this preview.").font(.subheadline).foregroundStyle(.secondary)
                    if deletingSourceID != nil {
                        Text("Deleting removes this source and its saved files, extracted reports, linked questions and copies inside checkpoints. Connected appointment prompts and follow-through plans are removed or cleared. Handoff copies that include this source become unavailable, and locally prepared exports are cleared. A task disappearing here does not mean it was completed.").font(.subheadline)
                    }
                }
                switch result {
                case .success(let comparison):
                    ComparisonSections(comparison: comparison)
                    if deletingSourceID != nil { Section { Button("Delete source and linked evidence", role: .destructive) { confirmDelete = true }.accessibilityIdentifier("impact-delete") } }
                case .failure(let error):
                    Section { Text(error.localizedDescription).foregroundStyle(Theme.warning) }
                }
            }.navigationTitle(deletingSourceID == nil ? "Impact preview" : "Deletion preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Permanently delete this source?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete source", role: .destructive) { if let deletingSourceID, store.deleteSource(deletingSourceID) { dismiss(); onDeleted() } }
                } message: { Text("Handoff copies using this evidence will also be removed. Other saved care remains. Previously shared copies cannot be deleted remotely.") }
        }
    }
}
