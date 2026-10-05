import SwiftUI
import CareCore

struct QuestionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Question
    private let original: Question
    @State private var discarding = false
    @FocusState private var editingQuestion: Bool
    init(question: Question) { original = question; _draft = State(initialValue: question) }
    private var hasChanges: Bool { draft != original }
    var body: some View {
        NavigationStack {
            Form {
                Section("Question") { TextField("What would you like to ask?", text: $draft.text, axis: .vertical).focused($editingQuestion).accessibilityIdentifier("question-edit-text") }
                Section("Answer or follow-up note") {
                    EvidenceTextEditor(text: $draft.answer, identifier: "question-edit-answer", placeholder: "Write or paste what you heard.", minimumHeight: 150, accessibilityName: "Answer or follow-up note")
                    Toggle("Answered", isOn: $draft.answered)
                    Text("An answer saved here is your note. To update My Care, capture the new information as a source and review its claims.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Bring to an encounter") {
                    Picker("Encounter", selection: $draft.encounterID) {
                        Text("Any appointment").tag(UUID?.none)
                        ForEach(store.state.encounters) { Text($0.title).tag(Optional($0.id)) }
                    }
                }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Your question").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if hasChanges { discarding = true } else { dismiss() } } }
                if editingQuestion { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing text") { editingQuestion = false }.accessibilityIdentifier("question-edit-text-done") } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.mutate({ state in
                            guard let index = state.questions.firstIndex(where: { $0.id == draft.id }) else { throw CareError.invalid("This question has been removed.") }
                            var value = draft; value.text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            state.questions[index] = value; state.audit.append(Audit(action: "question_updated"))
                        }) { dismiss() }
                    }.disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("question-edit-save")
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("Discard unsaved question changes?", isPresented: $discarding) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("Your saved question and answer stay unchanged. These edits will be lost.") }
        }
    }
}

struct EncounterEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EncounterRecord
    private let original: EncounterRecord
    @State private var deleting = false
    @State private var discarding = false
    private enum Field: Hashable { case title, provider }
    @FocusState private var focused: Field?
    init(encounter: EncounterRecord) { original = encounter; _draft = State(initialValue: encounter) }
    private var hasChanges: Bool { draft != original }
    private var exists: Bool { store.state.encounters.contains { $0.id == draft.id } }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Encounter title", text: $draft.title, axis: .vertical).focused($focused, equals: .title).accessibilityIdentifier("encounter-edit-title")
                TextField("Provider or practice", text: $draft.provider, axis: .vertical).focused($focused, equals: .provider).accessibilityIdentifier("encounter-edit-provider")
                OptionalDateField(title: "Event date", date: $draft.date)
                Text("An encounter groups sources and questions from the same visit. Editing its label does not rewrite clinical claims or their event dates.").font(.caption).foregroundStyle(.secondary)
                if exists { Section { Button("Remove encounter grouping", role: .destructive) { deleting = true } } }
            }.scrollDismissesKeyboard(.interactively).navigationTitle(exists ? "Edit encounter" : "New encounter").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if hasChanges { discarding = true } else { dismiss() } } }
                if focused != nil { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing text") { focused = nil }.accessibilityIdentifier("encounter-edit-done") } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.mutate({ state in
                            var value = draft; value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let index = state.encounters.firstIndex(where: { $0.id == value.id }) { state.encounters[index] = value }
                            else { state.encounters.append(value) }
                            state.audit.append(Audit(action: "encounter_saved"))
                        }) { dismiss() }
                    }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("encounter-edit-save")
                }
            }.confirmationDialog("Remove this grouping?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Remove grouping", role: .destructive) {
                    if store.mutate({ state in
                        state.encounters.removeAll { $0.id == draft.id }
                        ContinuityEngine.detachEncounter(draft.id, in: &state)
                        HandoffEngine.detachEncounter(draft.id, in: &state)
                        VisitCompanionEngine.detachEncounter(draft.id, from: &state)
                        FollowThroughAssistEngine.detachEncounter(draft.id, from: &state)
                        for i in state.sources.indices where state.sources[i].encounterID == draft.id { state.sources[i].encounterID = nil }
                        for i in state.questions.indices where state.questions[i].encounterID == draft.id { state.questions[i].encounterID = nil }
                        Reconciler.rebuild(&state); state.audit.append(Audit(action: "encounter_removed"))
                    }) { dismiss() }
                }
            } message: { Text("Sources, reviewed care, and questions remain saved. Only their encounter grouping is removed.") }
            .interactiveDismissDisabled(hasChanges)
            .alert("Discard unsaved encounter changes?", isPresented: $discarding) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            } message: { Text("Your saved records and encounter grouping stay unchanged. These edits will be lost.") }
        }
    }
}

struct NoteEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note: Note
    private let original: Note
    let isNew: Bool
    @State private var discarding = false
    @State private var deleting = false
    init(note: Note, isNew: Bool = false) { original = note; _note = State(initialValue: note); self.isNew = isNew }
    private var hasChanges: Bool { note != original }
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal note") { EvidenceTextEditor(text: $note.text, identifier: "personal-note-text", placeholder: "Write or paste a thought to carry forward.", minimumHeight: 180, accessibilityName: "Personal note") }
                Section("Optional care item") {
                    Picker("Related item", selection: $note.entityID) {
                        Text("General note").tag(UUID?.none)
                        ForEach(store.state.entities) { Text($0.label).tag(Optional($0.id)) }
                    }
                }
                Section { Text("A personal note is your context, not a verified clinical claim.").font(.caption) }
                Button("Save changes") {
                    if store.mutate({ state in
                        if isNew { state.notes.append(note) }
                        else {
                            guard let index = state.notes.firstIndex(where: { $0.id == note.id }) else { throw CareError.invalid("This note was removed.") }
                            state.notes[index] = note
                        }
                    }) { dismiss() }
                }.disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !isNew { Button("Delete note", role: .destructive) { deleting = true } }
            }.scrollDismissesKeyboard(.interactively).navigationTitle(isNew ? "New note" : "Edit note")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if hasChanges { discarding = true } else { dismiss() } } } }
                .interactiveDismissDisabled(hasChanges)
                .alert("Discard unsaved note changes?", isPresented: $discarding) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                } message: { Text("Your saved personal notes stay unchanged. These edits will be lost.") }
                .confirmationDialog("Delete this personal note?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete note permanently", role: .destructive) {
                        if store.mutate({ $0.notes.removeAll { $0.id == note.id } }) { dismiss() }
                    }
                } message: { Text("This removes the saved note and any unsaved edits. Sources and reviewed care stay saved.") }
        }
    }
}
