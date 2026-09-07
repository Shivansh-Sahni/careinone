import SwiftUI
import CareCore

struct ReviewEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Claim
    @State private var draft: Claim
    @State private var number: String
    @State private var interval: String
    @State private var confirmed = false
    @State private var issue: String?
    init(claim: Claim) { original = claim; _draft = State(initialValue: claim); _number = State(initialValue: claim.numericValue.map(String.init(describing:)) ?? ""); _interval = State(initialValue: claim.intervalDays.map(String.init) ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                Section("Supporting evidence") {
                    Text("“\(draft.quote)”").font(.subheadline).textSelection(.enabled)
                    if let source = store.source(draft.sourceID) { Text(source.title + " · " + source.kind.rawValue).font(.caption).foregroundStyle(.secondary) }
                    if let page = draft.page { Text("PDF page \(page)").font(.caption) }
                    if let seconds = draft.transcriptSeconds { Text("Transcript at \(Int(seconds)) seconds").font(.caption) }
                    Text("Model confidence: \(Int(draft.confidence * 100))% · This is not a measure of clinical correctness.").font(.caption).foregroundStyle(.secondary)
                }
                Section("What was reported") {
                    Picker("Category", selection: $draft.kind) { ForEach(EntityKind.allCases) { Text($0.title).tag($0) } }
                    TextField("Label", text: $draft.label)
                    Picker("Action", selection: $draft.action) { ForEach(ClaimAction.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    TextField("Value / instruction", text: $draft.value, axis: .vertical)
                    TextField("Numeric value", text: $number).keyboardType(.decimalPad)
                    TextField("Unit", text: $draft.unit)
                    if draft.kind == .medication { TextField("Route", text: $draft.route); TextField("Frequency", text: $draft.frequency); TextField("Form", text: $draft.form) }
                }
                Section("Dates") {
                    DisclosureGroup("Edit event, effective, or due date") {
                    OptionalDateField(title: "Event", date: $draft.eventAt)
                    OptionalDateField(title: "Effective", date: $draft.effectiveAt)
                    if draft.kind == .appointment { Toggle("Appointment time is known", isOn: $draft.dueTimeKnown) }
                    OptionalDateField(title: "Due / appointment", date: $draft.dueAt, time: draft.kind == .appointment && draft.dueTimeKnown)
                    Picker("Due-date precision", selection: $draft.duePrecision) { ForEach(DuePrecision.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    TextField("Follow-up interval in days", text: $interval).keyboardType(.numberPad)
                    Text("Relative dates use the medical event date. Upload time never becomes a medical event date.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Meaning & attribution") {
                    Picker("About", selection: $draft.subject) { ForEach(Subject.allCases, id: \.self) { Text($0 == .patient ? "Me" : $0.rawValue.capitalized).tag($0) } }
                    Picker("State", selection: $draft.certainty) { ForEach(Certainty.allCases.filter { $0 != .superseded }, id: \.self) { Text($0.rawValue).tag($0) } }
                    DisclosureGroup("Conditionality, negation & speaker") {
                    Toggle("Conditional / only if", isOn: $draft.conditional)
                    Toggle("Negated / says this is not present", isOn: $draft.negated)
                    TextField("Speaker (if known)", text: Binding(get: { draft.speaker ?? "" }, set: { draft.speaker = $0.isEmpty ? nil : $0 }))
                    Toggle("Speaker is uncertain", isOn: $draft.speakerUncertain)
                    Button("Mark historical") { draft.certainty = .historical }
                    Button("Mark uncertain") { draft.certainty = .uncertain }
                    Button("Not about me") { draft.subject = .other }
                    }
                }
                Section("Connect to My Care") {
                    DisclosureGroup("Review association or explicit replacement") {
                    Picker("Entity association", selection: $draft.entityID) {
                        Text("Exact match or create new item").tag(UUID?.none)
                        ForEach(store.state.entities.filter { $0.kind == draft.kind }) { Text($0.label).tag(Optional($0.id)) }
                    }
                    ForEach(EntityResolver.candidates(for: draft, in: store.state.entities)) { candidate in
                        VStack(alignment: .leading, spacing: 4) { Text(candidate.label).font(.subheadline.bold()); Text("\(Int(candidate.score * 100))% · \(candidate.reason)").font(.caption).foregroundStyle(.secondary); if !candidate.automatic { Button("Associate with this item") { draft.entityID = candidate.id } } }
                    }
                    Picker("Explicitly replaces earlier claim", selection: $draft.supersedesID) {
                        Text("No replacement — preserve both").tag(UUID?.none)
                        ForEach(store.state.claims.filter { $0.canonical && $0.kind == draft.kind && $0.id != draft.id && ($0.entityID == draft.entityID || Normalizer.key($0.label) == Normalizer.key(draft.label)) }) { Text($0.summary).tag(Optional($0.id)) }
                    }
                    Text("Only choose replacement when the saved evidence explicitly says the earlier record is superseded. Otherwise, preserve both for clarification.").font(.caption).foregroundStyle(.secondary)
                    Picker("Related care item", selection: $draft.relatedEntityID) {
                        Text("No explicit relationship").tag(UUID?.none)
                        ForEach(store.state.entities) { Text($0.label + " · " + $0.kind.title).tag(Optional($0.id)) }
                    }
                    if draft.relatedEntityID != nil {
                        Picker("Relationship from this item", selection: $draft.relation) {
                            Text("Not specified").tag(RelationKind?.none)
                            ForEach(RelationKind.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                        }
                        Text("For a result, choose resultOf only when this source explicitly relates it to that test. Undated results can leave completion uncertain.").font(.caption).foregroundStyle(.secondary)
                    }
                    }
                }
                Section {
                    Toggle("This accurately reflects what was reported", isOn: $confirmed)
                    Text("This does not verify that an instruction is medically correct. Conflicting clinical instructions remain for you and your care team to clarify.").font(.caption).foregroundStyle(.secondary)
                    if let issue { Text(issue).foregroundStyle(Theme.warning) }
                    Button(draft.subject == .patient ? "Accept reviewed claim" : "Save as not about me") { save() }.buttonStyle(.borderedProminent).disabled(!confirmed || draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("accept-claim")
                    Button("Reject proposal", role: .destructive) { if store.reject(original) { dismiss() } }
                }
            }.navigationTitle("Review claim").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onChange(of: draft.kind) { _, _ in draft.entityID = nil; draft.supersedesID = nil }
        }
    }
    private func save() {
        if !number.isEmpty && Double(number) == nil { issue = "Enter a valid numeric value or leave it blank."; return }
        if !interval.isEmpty && Int(interval) == nil { issue = "Use whole days for the follow-up interval."; return }
        draft.numericValue = Double(number); draft.intervalDays = Int(interval)
        draft.userEdited = draft != original; if draft.userEdited { draft.revision += 1 }
        if draft.dueAt != nil && draft.duePrecision == .unknown { draft.duePrecision = .approximate }
        if draft.subject != .patient {
            if store.reject(draft) { dismiss() }
        } else if store.accept([draft]) { dismiss() }
    }
}
