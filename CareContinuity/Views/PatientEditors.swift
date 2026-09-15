import SwiftUI
import CareCore

struct QuestionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Question
    init(question: Question) { _draft = State(initialValue: question) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Question") { TextField("What would you like to ask?", text: $draft.text, axis: .vertical) }
                Section("Answer or follow-up note") {
                    TextEditor(text: $draft.answer).frame(minHeight: 150)
                    Toggle("Answered", isOn: $draft.answered)
                    Text("An answer saved here is your note. To update My Care, capture the new information as a source and review its claims.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Bring to an encounter") {
                    Picker("Encounter", selection: $draft.encounterID) {
                        Text("Any appointment").tag(UUID?.none)
                        ForEach(store.state.encounters) { Text($0.title).tag(Optional($0.id)) }
                    }
                }
            }.navigationTitle("Your question").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.mutate({ state in
                            guard let index = state.questions.firstIndex(where: { $0.id == draft.id }) else { throw CareError.invalid("This question has been removed.") }
                            var value = draft; value.text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            state.questions[index] = value; state.audit.append(Audit(action: "question_updated"))
                        }) { dismiss() }
                    }.disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EncounterEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EncounterRecord
    @State private var deleting = false
    init(encounter: EncounterRecord) { _draft = State(initialValue: encounter) }
    private var exists: Bool { store.state.encounters.contains { $0.id == draft.id } }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Encounter title", text: $draft.title)
                TextField("Provider or practice", text: $draft.provider)
                OptionalDateField(title: "Event date", date: $draft.date)
                Text("An encounter groups sources and questions from the same visit. Editing its label does not rewrite clinical claims or their event dates.").font(.caption).foregroundStyle(.secondary)
                if exists { Section { Button("Remove encounter grouping", role: .destructive) { deleting = true } } }
            }.navigationTitle(exists ? "Edit encounter" : "New encounter").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.mutate({ state in
                            var value = draft; value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let index = state.encounters.firstIndex(where: { $0.id == value.id }) { state.encounters[index] = value }
                            else { state.encounters.append(value) }
                            state.audit.append(Audit(action: "encounter_saved"))
                        }) { dismiss() }
                    }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.confirmationDialog("Remove this grouping?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Remove grouping", role: .destructive) {
                    if store.mutate({ state in
                        state.encounters.removeAll { $0.id == draft.id }
                        for i in state.sources.indices where state.sources[i].encounterID == draft.id { state.sources[i].encounterID = nil }
                        for i in state.questions.indices where state.questions[i].encounterID == draft.id { state.questions[i].encounterID = nil }
                        Reconciler.rebuild(&state); state.audit.append(Audit(action: "encounter_removed"))
                    }) { dismiss() }
                }
            } message: { Text("Sources, reviewed care, and questions remain saved. Only their encounter grouping is removed.") }
        }
    }
}
