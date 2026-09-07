import SwiftUI
import Charts
import CareCore

struct VisitsView: View {
    @Environment(AppStore.self) private var store
    @State private var showNew = false
    @State private var title = ""
    @State private var provider = ""
    @State private var date: Date?
    var body: some View {
        List {
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
            NavigationStack { Form { TextField("Encounter title", text: $title); TextField("Provider", text: $provider); OptionalDateField(title: "Event date", date: $date) }.navigationTitle("New encounter").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNew = false } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { _ = store.mutate { $0.encounters.append(EncounterRecord(title: title, date: date, provider: provider)) }; title = ""; provider = ""; date = nil; showNew = false }.disabled(title.isEmpty) } } }
        }
    }
}
struct PrepareView: View {
    @Environment(AppStore.self) private var store
    let encounterID: UUID?
    private var encounter: EncounterRecord? { store.state.encounters.first { $0.id == encounterID } }
    var body: some View {
        List {
            Section {
                Text(encounter?.title ?? "Carry the context into your next visit").font(.title2.bold())
                Text("Bring the sources, unresolved differences, and questions that matter to you.").font(.subheadline).foregroundStyle(.secondary)
                NavigationLink(value: Route.brief) { Label("Create a Care Brief", systemImage: "doc.richtext") }
            }
            Section("Records to clarify") {
                ForEach(store.state.conflicts.filter { $0.status == .unresolved }) { conflict in VStack(alignment: .leading, spacing: 8) { Text(conflict.reason).font(.headline); Text(conflict.question).font(.subheadline).foregroundStyle(.secondary); Button("Save question") { store.addQuestion(conflict.question, entity: conflict.entityID, encounter: encounterID) } } }
                NavigationLink("Open discrepancies", value: Route.conflicts)
            }
            Section("Open follow-through") {
                ForEach(store.state.loops.filter { [.open, .uncertain].contains($0.status) && (encounterID == nil || $0.encounterID == encounterID) }) { loop in VStack(alignment: .leading, spacing: 4) { Text(loop.title).font(.headline); Text(loop.timing()).font(.caption).foregroundStyle(.secondary) } }
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
    var body: some View {
        List {
            Section {
                Text("Ask your saved information").font(.title2.bold())
                Text("Find source-grounded excerpts from reviewed claims. This local tool cannot diagnose, recommend treatment, or choose between conflicting instructions.").font(.subheadline).foregroundStyle(.secondary)
                TextField("e.g. What is saved about metoprolol?", text: $query, axis: .vertical)
                Button("Find in my saved care", systemImage: "text.magnifyingglass") { Task { excerpts = (try? await LocalGroundedSynthesis().answer(query, state: store.state)) ?? []; asked = true } }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if asked && excerpts.isEmpty { Section { Text("I couldn’t find matching reviewed claims. This does not mean the event never happened. Try another phrase, search original sources, or add an update."); NavigationLink("Search original sources", value: Route.search) } }
            ForEach(excerpts) { excerpt in
                Section {
                    Text(excerpt.summary).font(.headline)
                    if excerpt.disputed { Badge(text: "Conflicting reports saved · clarify with your care team", caution: true) }
                    Text("“\(excerpt.quote)”").font(.subheadline)
                    Text(excerpt.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Event date unknown").font(.caption).foregroundStyle(.secondary)
                    SourceLink(id: excerpt.sourceID)
                }
            }
            if asked { Section { Button("Save this as a question for my care team") { store.addQuestion(query) } } }
        }.navigationTitle("Ask").navigationBarTitleDisplayMode(.inline)
    }
}
struct QuestionsView: View {
    @Environment(AppStore.self) private var store
    let entityID: UUID?
    @State private var text = ""
    @State private var all = false
    var body: some View {
        List {
            Section("Capture a question") { TextField("What do you want to ask?", text: $text, axis: .vertical); Button("Save question") { store.addQuestion(text, entity: entityID); text = "" }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            Section { Toggle("Include answered questions", isOn: $all) }
            ForEach(store.state.questions.filter { (entityID == nil || $0.entityID == entityID) && (all || !$0.answered) }) { question in
                Section {
                    Text(question.text).font(.headline)
                    TextField("Your saved answer or follow-up note", text: Binding(get: { store.state.questions.first { $0.id == question.id }?.answer ?? "" }, set: { value in _ = store.mutate { state in if let i = state.questions.firstIndex(where: { $0.id == question.id }) { state.questions[i].answer = value } } }), axis: .vertical)
                    Toggle("Answered", isOn: Binding(get: { question.answered }, set: { value in _ = store.mutate { state in if let i = state.questions.firstIndex(where: { $0.id == question.id }) { state.questions[i].answered = value } } }))
                    if let source = question.sourceID { SourceLink(id: source) }
                    Button("Delete question", role: .destructive) { _ = store.mutate { $0.questions.removeAll { $0.id == question.id } } }
                }
            }
        }.navigationTitle("Questions")
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
        List {
            Section { Text("Trends display saved numeric results only. No interpretation, normal range, or diagnosis is inferred. Different units stay separate.").font(.subheadline).foregroundStyle(.secondary) }
            let entities = store.state.entities.filter { [.labTest, .resultType].contains($0.kind) }
            ForEach(entities) { entity in
                let claims = store.state.claims(for: entity.id).filter { $0.numericValue != nil && $0.eventAt != nil && !$0.negated && !$0.conditional }
                let units = Array(Set(claims.map(\.unit))).sorted()
                ForEach(units, id: \.self) { unit in
                    let series = claims.filter { $0.unit == unit }.sorted { $0.eventAt! < $1.eventAt! }
                    Section(entity.label + " · " + (unit.isEmpty ? "unit not provided" : unit)) {
                        Chart(series) { claim in
                            LineMark(x: .value("Event date", claim.eventAt!), y: .value("Saved value", claim.numericValue!)).foregroundStyle(Theme.accent)
                            PointMark(x: .value("Event date", claim.eventAt!), y: .value("Saved value", claim.numericValue!)).foregroundStyle(Theme.accent)
                        }.frame(height: 210).accessibilityLabel("Saved values for \(entity.label). Exact values and source links are listed below.")
                        ForEach(series) { claim in VStack(alignment: .leading, spacing: 5) { Text("\(claim.numericValue!.formatted()) \(unit) · \(claim.eventAt!.formatted(date: .abbreviated, time: .omitted))"); SourceLink(id: claim.sourceID) } }
                    }
                }
            }
            if !store.state.claims.contains(where: { $0.canonical && [.labTest, .resultType].contains($0.kind) && $0.numericValue != nil && $0.eventAt != nil }) { ContentUnavailableView("No dated numeric results yet", systemImage: "chart.xyaxis.line", description: Text("Add and review a result with a value, unit, and event date.")) }
        }.navigationTitle("Trends")
    }
}
