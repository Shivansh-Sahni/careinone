import SwiftUI
import Charts
import CareCore

struct VisitsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false
    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.visitCompanions) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Appointment companion", systemImage: "person.crop.rectangle.badge.plus").font(.headline)
                        Text("Know what to say. Ask what matters. Keep the answers.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }.accessibilityIdentifier("visits-companion")
            }
            Section {
                NavigationLink(value: Route.continuity) { Label("Visit workspaces", systemImage: "rectangle.3.group") }.accessibilityIdentifier("visits-workspaces")
                NavigationLink(value: Route.checkpoints) { Label("Care checkpoints", systemImage: "clock.arrow.circlepath") }
                NavigationLink(value: Route.handoffs) { Label("Tracked handoffs", systemImage: "arrow.up.doc.on.clipboard") }.accessibilityIdentifier("visits-handoffs")
            }
            Section("Next appointments") {
                let appointments = store.state.upcomingAppointments()
                if appointments.isEmpty { Text("No upcoming appointments have been added here.").foregroundStyle(.secondary) }
                ForEach(appointments) { claim in NavigationLink(value: Route.entity(claim.entityID!)) { VStack(alignment: .leading, spacing: 5) { Text(claim.label).font(.headline); Text((claim.dueAt ?? claim.eventAt)!.formatted(date: .abbreviated, time: claim.dueTimeKnown ? .shortened : .omitted) + (claim.dueTimeKnown ? "" : " · time not provided")).font(.subheadline).foregroundStyle(.secondary) } } }
                NavigationLink(value: Route.prepare(nil)) { Label("Prepare for your next visit", systemImage: "list.bullet.clipboard") }
            }
            Section("Encounters") {
                Button("Add an encounter", systemImage: "calendar.badge.plus") { showNew = true }
                ForEach(store.state.encounters.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) { encounter in
                    NavigationLink(value: Route.prepare(encounter.id)) { VStack(alignment: .leading, spacing: 5) { Text(encounter.title).font(.headline); Text(encounter.provider).font(.subheadline); Text(encounter.date?.formatted(date: .abbreviated, time: .omitted) ?? "Event date unknown").font(.caption).foregroundStyle(.secondary); Text("\(store.state.sources.filter { $0.encounterID == encounter.id }.count) linked sources").font(.caption).foregroundStyle(Theme.accent) } }
                }
            }
        }.navigationTitle("Visits").sheet(isPresented: $showNew) {
            EncounterEditor(encounter: EncounterRecord(title: ""))
        }
    }
}
struct PrepareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    let encounterID: UUID?
    @State private var editing: EncounterRecord?
    private var encounter: EncounterRecord? { store.state.encounters.first { $0.id == encounterID } }
    var body: some View {
        List {
            Section {
                Text(encounter?.title ?? "Carry the context into your next visit").font(.title2.bold())
                Text("Bring the sources, unresolved differences, and questions that matter to you.").font(.subheadline).foregroundStyle(.secondary)
                Button("Start my appointment companion", systemImage: "person.crop.rectangle.badge.plus") {
                    if let id = store.startVisitCompanion(title: encounter?.title ?? "My next appointment", encounterID: encounterID) { navigate(.visitCompanion(id)) }
                }.accessibilityIdentifier("prepare-companion")
                NavigationLink { VisitPacketView(encounterID: encounterID) } label: { Label("Choose a visit packet", systemImage: "list.bullet.clipboard") }
                if let encounter {
                    Button("Open a connected visit workspace", systemImage: "rectangle.3.group") { if let id = store.createWorkspace(title: encounter.title, encounterID: encounter.id) { navigate(.workspace(id)) } }
                } else { NavigationLink("Open visit workspaces", value: Route.continuity) }
                NavigationLink(value: Route.brief) { Label("Create a complete Care Brief", systemImage: "doc.richtext") }
                if let encounter { Button("Edit encounter details") { editing = encounter } }
            }
            Section("Records to clarify") {
                ForEach(store.state.conflicts.filter { $0.status == .unresolved }) { conflict in VStack(alignment: .leading, spacing: 8) { Text(conflict.reason).font(.headline); Text(conflict.question).font(.subheadline).foregroundStyle(.secondary); Button("Save question") { store.addQuestion(conflict.question, entity: conflict.entityID, encounter: encounterID) } } }
                NavigationLink("Open discrepancies", value: Route.conflicts)
            }
            Section("Open follow-through across my care") {
                ForEach(store.state.loops.filter { [.open, .uncertain].contains($0.status) }) { loop in
                    NavigationLink(value: Route.followThroughHelp(loop.id)) {
                        VStack(alignment: .leading, spacing: 4) { Text(loop.title).font(.headline); Text(loop.timing()).font(.caption).foregroundStyle(.secondary); Text("Help me get this done").font(.caption).foregroundStyle(Theme.accent) }
                    }
                }
                NavigationLink("Manage follow-through", value: Route.loops)
            }
            Section("Your questions") {
                ForEach(store.state.questions.filter { !$0.answered && (encounterID == nil || $0.encounterID == nil || $0.encounterID == encounterID) }) { Text($0.text) }
                NavigationLink("Write or answer a question", value: Route.questions(nil))
            }
            Section("Sources to carry") {
                ForEach(store.state.sources.filter { encounterID == nil || $0.encounterID == encounterID }.sorted { $0.capturedAt > $1.capturedAt }.prefix(20)) { SourceLink(id: $0.id) }
            }
        }.navigationTitle(encounter == nil ? "Prepare" : "Encounter").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { EncounterEditor(encounter: $0) }
    }
}
struct SearchView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    var body: some View {
        List {
            if query.isEmpty { ContentUnavailableView("Find your saved context", systemImage: "magnifyingglass", description: Text("Search claims, source text, providers, questions, and personal notes.")) }
            let hits = SearchEngine.search(query, state: store.state)
            if !query.isEmpty && hits.isEmpty { Text("No matches in the information saved here.").foregroundStyle(.secondary) }
            ForEach(hits) { hit in
                VStack(alignment: .leading, spacing: 8) {
                    Text(hit.title).font(.headline); Badge(text: hit.type); Text(hit.excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(5)
                    if let source = hit.sourceID { SourceLink(id: source) }
                    if let entity = hit.entityID { NavigationLink("View care item", value: Route.entity(entity)) }
                    if hit.type == "Note" { NavigationLink("View personal notes", value: Route.notes) }
                    if hit.type == "Question" { NavigationLink("View questions", value: Route.questions(hit.entityID)) }
                }.padding(.vertical, 4)
            }
        }.navigationTitle("Search").searchable(text: $query, prompt: "Name, phrase, provider, or question")
    }
}
struct AskView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var excerpts: [GroundedExcerpt] = []
    @State private var asked = false
    @State private var answeredQuery = ""
    @State private var answeredState: CareState?
    @State private var searching = false
    @State private var searchError: String?
    @State private var requestID: UUID?
    @State private var searchTask: Task<Void, Never>?
    private var currentAnswer: Bool { asked && answeredQuery == query && answeredState == store.state }
    var body: some View {
        List {
            Section {
                Text("Ask your saved information").font(.title2.bold())
                Text("Find source-grounded excerpts from reviewed claims. This local tool cannot diagnose, recommend treatment, or choose between conflicting instructions.").font(.subheadline).foregroundStyle(.secondary)
                TextField("e.g. What is saved about metoprolol?", text: $query, axis: .vertical).accessibilityIdentifier("ask-query")
                Button("Find in my saved care", systemImage: "text.magnifyingglass") { findSavedCare() }.disabled(searching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("ask-find")
                if searching { ProgressView("Finding your saved excerpts…") }
                if let searchError { Text(searchError).foregroundStyle(Theme.warning) }
            }
            if currentAnswer && excerpts.isEmpty { Section { Text("I couldn’t find matching reviewed claims. This does not mean the event never happened. Try another phrase, search original sources, or add an update."); NavigationLink("Search original sources", value: Route.search) } }
            ForEach(currentAnswer ? excerpts : []) { excerpt in
                Section {
                    Text(excerpt.summary).font(.headline)
                    Text(excerpt.context).font(.caption).foregroundStyle(.secondary)
                    if excerpt.disputed { Badge(text: "Conflicting reports saved · clarify with your care team", caution: true) }
                    Text("“\(excerpt.quote)”").font(.subheadline).accessibilityIdentifier("ask-quote-" + excerpt.id.uuidString)
                    Text(excerpt.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Event date unknown").font(.caption).foregroundStyle(.secondary)
                    SourceLink(id: excerpt.sourceID)
                }
            }
            if currentAnswer { Section { Button("Save this as a question for my care team") { store.addQuestion(query) } } }
        }.navigationTitle("Ask").navigationBarTitleDisplayMode(.inline)
            .onChange(of: query) { clearAnswer() }
            .onChange(of: store.state) { clearAnswer() }
            .onDisappear { cancelSearch() }
    }
    private func cancelSearch() {
        searchTask?.cancel(); searchTask = nil; requestID = nil; searching = false
    }
    private func clearAnswer() {
        cancelSearch(); excerpts = []; asked = false; answeredQuery = ""; answeredState = nil; searchError = nil
    }
    private func findSavedCare() {
        clearAnswer()
        let question = query, snapshot = store.state, run = UUID()
        requestID = run; searching = true
        searchTask = Task { @MainActor in
            do {
                let result = try await LocalGroundedSynthesis().answer(question, state: snapshot)
                guard !Task.isCancelled, requestID == run, query == question, store.state == snapshot else { return }
                excerpts = result; answeredQuery = question; answeredState = snapshot; asked = true
                searching = false; searchTask = nil; requestID = nil
            } catch {
                guard !Task.isCancelled, requestID == run, query == question, store.state == snapshot else { return }
                searching = false; searchTask = nil; requestID = nil
                searchError = "Saved-care search did not finish. Try again; your saved information is unchanged."
            }
        }
    }
}
struct QuestionsView: View {
    @Environment(AppStore.self) private var store
    let entityID: UUID?
    @State private var text = ""
    @State private var all = false
    @State private var editing: Question?
    @State private var deleting: Question?
    @FocusState private var enteringQuestion: Bool
    var body: some View {
        List {
            Section("Capture a question") { TextField("What do you want to ask?", text: $text, axis: .vertical).focused($enteringQuestion); Button("Save question") { if store.addQuestion(text, entity: entityID) { text = ""; enteringQuestion = false } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            Section { Toggle("Include answered questions", isOn: $all) }
            ForEach(store.state.questions.filter { (entityID == nil || $0.entityID == entityID) && (all || !$0.answered) }) { question in
                Section {
                    Text(question.text).font(.headline)
                    if !question.answer.isEmpty { Text(question.answer).font(.subheadline).textSelection(.enabled) }
                    Badge(text: question.answered ? "Answered" : "Ready to ask")
                    Button(question.answer.isEmpty ? "Add an answer or edit" : "Edit question and answer") { editing = question }
                    if let source = question.sourceID { SourceLink(id: source) }
                    Button("Delete question", role: .destructive) { deleting = question }
                }
            }
        }.scrollDismissesKeyboard(.interactively).navigationTitle("Questions").sheet(item: $editing) { QuestionEditor(question: $0) }
            .toolbar {
                if enteringQuestion { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing question") { enteringQuestion = false }.accessibilityIdentifier("question-entry-done") } }
            }
            .alert("Delete this question and its answer?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                if let question = deleting {
                    Button("Delete question permanently", role: .destructive) {
                        _ = store.mutate { state in
                            guard state.questions.first(where: { $0.id == question.id }) == question else { throw CareError.invalid("This question changed. Review its current version before deleting it.") }
                            state.questions.removeAll { $0.id == question.id }
                        }
                        deleting = nil
                    }
                }
                Button("Keep question", role: .cancel) { deleting = nil }
            } message: {
                Text("The saved question and answer will be removed. Copies already made in appointment preparation or exported files remain separate.")
            }
    }
}
struct CareNetworkView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section { Text("People and practices named in your saved sources. Similar provider names are not automatically merged.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(Array(Set(store.state.sources.map(\.provider).filter { !$0.isEmpty })).sorted(), id: \.self) { provider in
                Section(provider) { ForEach(store.state.sources.filter { $0.provider == provider }) { SourceLink(id: $0.id) } }
            }
            Section("Reviewed care-team items") { ForEach(store.state.entities.filter { $0.kind == .provider }) { entity in NavigationLink(entity.label, value: Route.entity(entity.id)) } }
        }.navigationTitle("Care Network")
    }
}
struct TrendsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let series = NumericTrendPolicy.series(in: store.state)
        List {
            Section { Text("Only reviewed, available numeric results with a recorded date appear here. Superseded and uncertain reports stay in My Care and Sources. No interpretation, normal range, or diagnosis is inferred. Different units stay separate.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(series) { values in
                Section(values.entity.label + " · " + (values.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unit not provided" : values.unit)) {
                    if values.hasUnresolvedDiscrepancy {
                        Label("These source reports have an unresolved discrepancy. Compare the values and sources; no trend line is drawn.", systemImage: "exclamationmark.triangle").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if values.hasMultipleValuesOnDate {
                        Label("More than one value is reported on the same date. They may be separate measurements. Compare the sources before treating them as a trend.", systemImage: "doc.on.doc").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if values.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("The unit was not provided. Values are shown separately because their comparability is unknown.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Chart(values.points) { point in
                        if values.canConnectValues { LineMark(x: .value("Event date", point.date), y: .value("Saved value", point.value)).foregroundStyle(Theme.accent) }
                        PointMark(x: .value("Event date", point.date), y: .value("Saved value", point.value)).foregroundStyle(Theme.accent)
                    }.frame(height: 210).chartYScale(domain: .automatic(includesZero: false)).accessibilityHidden(true)
                    ForEach(values.points) { point in
                        VStack(alignment: .leading, spacing: 5) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(point.value.formatted()) \(values.unit) · \(point.date.formatted(date: .abbreviated, time: .omitted))").font(.headline)
                                Text(point.claim.certainty.displayLabel).font(.caption).foregroundStyle(.secondary)
                                if point.disputed { Text("Unresolved source discrepancy").font(.caption).foregroundStyle(.secondary) }
                                if point.multipleValuesOnDate { Text("Multiple values on this date").font(.caption).foregroundStyle(.secondary) }
                            }.accessibilityElement(children: .combine)
                            SourceLink(id: point.claim.sourceID)
                        }
                    }
                }
            }
            if series.isEmpty { ContentUnavailableView("No reviewed numeric results yet", systemImage: "chart.xyaxis.line", description: Text("Add and review an available result with a numeric value and event date. Other reports remain in My Care and Sources.")) }
        }.navigationTitle("Trends")
    }
}


struct PersonalNotesView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var editing: Note?
    @State private var creating = false
    var body: some View {
        List {
            Section { Text("Your thoughts and reminders stay separate from reviewed clinical claims. Notes remain available here if a linked care item is removed.").font(.subheadline).foregroundStyle(.secondary) }
            Button("Write a personal note", systemImage: "square.and.pencil") { creating = true }
            let notes = store.state.notes.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }.sorted { $0.createdAt > $1.createdAt }
            if notes.isEmpty { ContentUnavailableView("No matching notes", systemImage: "note.text", description: Text("Save a thought or something to bring up at your next visit.")) }
            ForEach(notes) { note in
                Section {
                    Text(note.text).textSelection(.enabled)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    if let entity = store.state.entity(note.entityID) { NavigationLink(entity.label, value: Route.entity(entity.id)) }
                    Button("Edit note") { editing = note }
                }
            }
        }.navigationTitle("Personal notes")
            .searchable(text: $search, prompt: "Search your notes")
            .sheet(item: $editing) { NoteEditor(note: $0) }
            .sheet(isPresented: $creating) { NoteEditor(note: Note(text: ""), isNew: true) }
    }
}
