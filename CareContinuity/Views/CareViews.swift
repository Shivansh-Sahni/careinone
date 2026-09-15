import SwiftUI
import CareCore

struct MyCareView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section { Text("A connected view of what your sources report. Conflicting and incomplete information stays visible.").font(.subheadline).foregroundStyle(.secondary) }
            Section("Your care memory") {
                ForEach(EntityKind.allCases) { kind in
                    NavigationLink(value: Route.category(kind)) { HStack { Label(kind.title, systemImage: kind.symbol); Spacer(); Text("\(store.state.entities.filter { $0.kind == kind }.count)").foregroundStyle(.secondary) } }
                }
            }
            Section("Work with your information") {
                NavigationLink(value: Route.loops) { Label("Follow-through", systemImage: "checklist") }
                NavigationLink(value: Route.questions(nil)) { Label("Questions", systemImage: "questionmark.bubble") }
                NavigationLink(value: Route.trends) { Label("Trends", systemImage: "chart.xyaxis.line") }
                NavigationLink(value: Route.network) { Label("Care Network", systemImage: "person.2") }
                NavigationLink(value: Route.brief) { Label("Care Brief", systemImage: "doc.richtext") }
                NavigationLink(value: Route.search) { Label("Search everything saved", systemImage: "magnifyingglass") }
            }
        }.navigationTitle("My Care")
    }
}
struct CategoryView: View {
    @Environment(AppStore.self) private var store
    let kind: EntityKind
    @State private var search = ""
    var body: some View {
        List {
            let entities = store.state.entities.filter { $0.kind == kind && (search.isEmpty || $0.label.localizedCaseInsensitiveContains(search) || $0.aliases.contains { $0.localizedCaseInsensitiveContains(search) }) }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
            if entities.isEmpty { ContentUnavailableView("Nothing saved in this category", systemImage: kind.symbol, description: Text("This does not mean there is nothing in your medical history. Capture an update whenever it is useful.")) }
            ForEach(entities) { entity in
                NavigationLink(value: Route.entity(entity.id)) {
                    VStack(alignment: .leading, spacing: 8) { Text(entity.label).font(.headline); Badge(text: store.state.projection(for: entity.id).displayLabel, caution: store.state.projection(for: entity.id) == .conflicting); Text("\(store.state.claims(for: entity.id).count) source-linked claims").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle(kind.title).searchable(text: $search, prompt: "Search \(kind.title.lowercased())")
    }
}
struct EntityDetailView: View {
    @Environment(AppStore.self) private var store
    let id: UUID
    @State private var alias = ""
    @State private var note = ""
    var body: some View {
        ScrollView {
            if let entity = store.state.entity(id) {
                VStack(alignment: .leading, spacing: 20) {
                    CareCard {
                        Label(entity.label, systemImage: entity.kind.symbol).font(.title2.bold())
                        Badge(text: store.state.projection(for: id).displayLabel, caution: store.state.projection(for: id) == .conflicting)
                        Text("This view reflects saved reports. It does not choose which clinical instruction is correct.").font(.caption).foregroundStyle(.secondary)
                        if let code = entity.code { Text("\(entity.codeSystem ?? "Unspecified code system"): \(code)").font(.caption) }
                        if !entity.aliases.isEmpty { Text("Also saved as: " + entity.aliases.joined(separator: ", ")).font(.caption) }
                        DisclosureGroup("Add an alias you recognize") {
                            TextField("Alias", text: $alias).textFieldStyle(.roundedBorder)
                            Button("Save alias") { _ = store.mutate { state in if let i = state.entities.firstIndex(where: { $0.id == id }), !state.entities[i].aliases.contains(alias) { state.entities[i].aliases.append(alias) } }; alias = "" }.disabled(alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Text("Future exact alias matches can associate automatically. Only add a name that refers to this same item.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.state.conflicts.contains(where: { $0.entityID == id && $0.status == .unresolved }) { NavigationLink(value: Route.conflicts) { Label("Saved records disagree · open clarification inbox", systemImage: "text.bubble") }.buttonStyle(.bordered) }
                    if store.state.loops.contains(where: { $0.entityID == id }) { NavigationLink("Related follow-through", value: Route.loops).buttonStyle(.bordered) }
                    NavigationLink(value: Route.questions(id)) { Label("Questions about this item", systemImage: "questionmark.bubble") }
                    SectionHeading(title: "History & source evidence", subtitle: "Medical event dates are shown separately from acceptance time.")
                    let superseded = Set(store.state.relations.filter { $0.kind == .supersedes }.map(\.to))
                    ForEach(store.state.claims(for: id).sorted { ($0.eventAt ?? .distantPast) > ($1.eventAt ?? .distantPast) }) { claim in
                        CareCard {
                            ClaimSummary(claim: claim)
                            if superseded.contains(claim.id) { Badge(text: "Explicitly superseded") }
                            if claim.negated { Badge(text: "Negated statement", caution: true) }; if claim.conditional { Badge(text: "Conditional", caution: true) }
                            Text("“\(claim.quote)”").font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                            if let page = claim.page { Text("Page \(page)").font(.caption) }
                            if let effective = claim.effectiveAt { Text("Effective \(effective.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                            Text("Review: \(claim.review.displayLabel) · revision \(claim.revision)" + (claim.userEdited ? " · edited by you" : "")).font(.caption).foregroundStyle(.secondary)
                            SourceLink(id: claim.sourceID)
                            if claim.kind == .appointment && claim.dueAt != nil && claim.duePrecision == .exact && !superseded.contains(claim.id) && ![.historical, .superseded].contains(claim.certainty) { Button("Add to Calendar") { Task { do { try await CalendarService.addAppointment(claim); store.notice = "Appointment added to your calendar. Check the saved time and duration." } catch { store.error = error.localizedDescription } } } }
                        }
                    }
                    let encounters = Set(store.state.sources.filter { source in store.state.claims(for: id).contains { $0.sourceID == source.id } }.compactMap(\.encounterID))
                    if !encounters.isEmpty { SectionHeading(title: "Related encounters"); ForEach(store.state.encounters.filter { encounters.contains($0.id) }) { encounter in NavigationLink(encounter.title, value: Route.prepare(encounter.id)) } }
                    CareCard {
                        Text("Your notes").font(.headline)
                        ForEach(store.state.notes.filter { $0.entityID == id }) { note in Text(note.text).font(.subheadline) }
                        TextField("A thought to carry forward", text: $note, axis: .vertical)
                        Button("Save note") { _ = store.mutate { $0.notes.append(Note(text: note, entityID: id)) }; note = "" }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(20)
            } else { ContentUnavailableView("No accepted claims remain", systemImage: "square.stack") }
        }.background(Theme.background).navigationTitle("Care item").navigationBarTitleDisplayMode(.inline)
    }
}

struct ChangesView: View {
    @Environment(AppStore.self) private var store
    @State private var category: EntityKind?
    @State private var provider = ""
    @State private var since: Date?
    @State private var groupEncounters = true
    private var changes: [Change] {
        store.state.changes.filter { (category == nil || $0.category == category) && (provider.isEmpty || store.source($0.sourceID)?.provider == provider) && (since == nil || $0.date >= since!) }
    }
    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) { Text("All categories").tag(EntityKind?.none); ForEach(EntityKind.allCases) { Text($0.title).tag(Optional($0)) } }
                Picker("Provider", selection: $provider) { Text("All providers").tag(""); ForEach(Array(Set(store.state.sources.map(\.provider).filter { !$0.isEmpty })).sorted(), id: \.self) { Text($0).tag($0) } }
                OptionalDateField(title: "Since", date: $since)
                Toggle("Group by encounter", isOn: $groupEncounters)
            }
            if changes.isEmpty { ContentUnavailableView("No changes in this view", systemImage: "arrow.triangle.2.circlepath", description: Text("Accepted claims create a change history automatically.")) }
            let groups = Dictionary(grouping: changes) { groupEncounters ? ($0.encounterID ?? $0.setID) : $0.setID }
            let keys = groups.keys.sorted { (groups[$0]?.first?.date ?? .distantPast) > (groups[$1]?.first?.date ?? .distantPast) }
            ForEach(keys, id: \.self) { key in
                Section(store.state.encounters.first { $0.id == key }?.title ?? store.source(key)?.title ?? "Care update") {
                    ForEach(groups[key] ?? []) { change in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Badge(text: change.kind.displayLabel, caution: change.kind == .conflictIntroduced); Spacer(); Text(change.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                            if let before = change.before { Text("Before: " + before).font(.subheadline).foregroundStyle(.secondary) }
                            Text("After: " + change.after).font(.subheadline.weight(.medium))
                            SourceLink(id: change.sourceID)
                        }.padding(.vertical, 5)
                    }
                }
            }
        }.navigationTitle("What Changed")
    }
}
