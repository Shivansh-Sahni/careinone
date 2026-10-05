import SwiftUI
import CareCore

struct MyCareView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section { Text("A connected view of what your sources report. Conflicting and incomplete information stays visible.").font(.subheadline).foregroundStyle(.secondary) }
            Section {
                NavigationLink(value: Route.intelligence) { Label("Care connections", systemImage: "point.3.connected.trianglepath.dotted") }.accessibilityIdentifier("care-connections")
            }
            Section("Your care memory") {
                ForEach(EntityKind.allCases) { kind in
                    NavigationLink(value: Route.category(kind)) { HStack { Label(kind.title, systemImage: kind.symbol); Spacer(); Text("\(store.state.entities.filter { $0.kind == kind }.count)").foregroundStyle(.secondary) } }
                }
            }
            Section("Work with your information") {
                NavigationLink(value: Route.loops) { Label("Follow-through", systemImage: "checklist") }
                NavigationLink(value: Route.questions(nil)) { Label("Questions", systemImage: "questionmark.bubble") }
                NavigationLink(value: Route.notes) { Label("Personal notes", systemImage: "note.text") }
                NavigationLink(value: Route.trends) { Label("Trends", systemImage: "chart.xyaxis.line") }
                NavigationLink(value: Route.network) { Label("Care Network", systemImage: "person.2") }
                NavigationLink(value: Route.brief) { Label("Care Brief", systemImage: "doc.richtext") }
                NavigationLink(value: Route.search) { Label("Search saved care and sources", systemImage: "magnifyingglass") }
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
    @State private var removingAlias: String?
    @State private var note = ""
    @State private var editingNote: Note?
    @State private var addingToCalendar = Set<UUID>()
    @State private var repeatCalendarClaim: Claim?
    var body: some View {
        ScrollView {
            if let entity = store.state.entity(id) {
                VStack(alignment: .leading, spacing: 20) {
                    CareCard {
                        Label(entity.label, systemImage: entity.kind.symbol).font(.title2.bold())
                        Badge(text: store.state.projection(for: id).displayLabel, caution: store.state.projection(for: id) == .conflicting)
                        Text("This view reflects saved reports. It does not choose which clinical instruction is correct.").font(.caption).foregroundStyle(.secondary)
                        if let code = entity.code { Text("\(entity.codeSystem ?? "Unspecified code system"): \(code)").font(.caption) }
                        if !entity.aliases.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Also saved as").font(.caption.bold())
                                ForEach(Array(entity.aliases.enumerated()), id: \.offset) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.element).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                        Button("Remove alias", role: .destructive) { removingAlias = entry.element }
                                            .accessibilityLabel("Remove alias " + entry.element)
                                    }
                                }
                            }
                        }
                        DisclosureGroup("Add an alias you recognize") {
                            TextField("Alias", text: $alias, axis: .vertical).textFieldStyle(.roundedBorder)
                            Button("Save alias") {
                                if store.mutate({ try EntityAliasPolicy.add(alias, to: id, in: &$0) }) { alias = "" }
                            }.disabled(alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Text("Future exact alias matches can associate automatically. Only add a name that refers to this same item. Removing an alias stops future matching by that name; existing reviewed associations stay unchanged.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.state.conflicts.contains(where: { $0.entityID == id && $0.status == .unresolved }) { NavigationLink(value: Route.conflicts) { Label("Saved records disagree · open clarification inbox", systemImage: "text.bubble") }.buttonStyle(.bordered) }
                    if store.state.loops.contains(where: { $0.entityID == id }) { NavigationLink("Related follow-through", value: Route.loops).buttonStyle(.bordered) }
                    NavigationLink(value: Route.questions(id)) { Label("Questions about this item", systemImage: "questionmark.bubble") }
                    NavigationLink(value: Route.evidenceMap(.entity(id))) { Label("Trace the evidence behind this item", systemImage: "point.3.connected.trianglepath.dotted") }
                    NavigationLink(value: Route.evidenceTimeline(id)) { Label("Medical dates and when added here", systemImage: "calendar.badge.clock") }
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
                            if AppointmentCalendarPolicy.canExport(claim, in: store.state) {
                                if store.isDemoWorkspace { Text("Fictional practice keeps your personal calendar unchanged.").font(.caption).foregroundStyle(.secondary) }
                                else {
                                    Button(addingToCalendar.contains(claim.id) ? "Saving to Calendar…" : "Add to Calendar") { exportCalendar(claim) }
                                        .disabled(addingToCalendar.contains(claim.id))
                                        .accessibilityIdentifier("appointment-calendar-" + claim.id.uuidString)
                                    if CalendarService.hasExport(claim) {
                                        Text("You previously exported this appointment. Changes here do not update the calendar copy.").font(.caption).foregroundStyle(.secondary)
                                        Button("Add another calendar copy…") { repeatCalendarClaim = claim }.disabled(addingToCalendar.contains(claim.id))
                                    }
                                }
                            }
                        }
                    }
                    let encounters = Set(store.state.sources.filter { source in store.state.claims(for: id).contains { $0.sourceID == source.id } }.compactMap(\.encounterID))
                    if !encounters.isEmpty { SectionHeading(title: "Related encounters"); ForEach(store.state.encounters.filter { encounters.contains($0.id) }) { encounter in NavigationLink(encounter.title, value: Route.prepare(encounter.id)) } }
                    CareCard {
                        Text("Your notes").font(.headline)
                        ForEach(store.state.notes.filter { $0.entityID == id }) { note in
                            VStack(alignment: .leading) { Text(note.text).font(.subheadline); Button("Edit note") { editingNote = note } }
                        }
                        TextField("A thought to carry forward", text: $note, axis: .vertical)
                        Button("Save note") { if store.mutate({ $0.notes.append(Note(text: note, entityID: id)) }) { note = "" } }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(20)
            } else { ContentUnavailableView("No accepted claims remain", systemImage: "square.stack") }
        }.background(Theme.background).navigationTitle("Care item").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingNote) { NoteEditor(note: $0) }
            .confirmationDialog("Remove this alias?", isPresented: Binding(get: { removingAlias != nil }, set: { if !$0 { removingAlias = nil } }), titleVisibility: .visible) {
                if let savedAlias = removingAlias {
                    Button("Remove alias", role: .destructive) {
                        if store.mutate({ try EntityAliasPolicy.remove(savedAlias, from: id, in: &$0) }) {
                            store.notice = "Alias removed. Existing reviewed care and source associations stay unchanged."
                        }
                        removingAlias = nil
                    }
                }
                Button("Keep alias", role: .cancel) { removingAlias = nil }
            } message: { Text("This stops future matching by this saved name. It does not unlink or change already reviewed claims, sources or clinical reports.") }
            .confirmationDialog("Add another calendar copy?", isPresented: Binding(get: { repeatCalendarClaim != nil }, set: { if !$0 { repeatCalendarClaim = nil } }), titleVisibility: .visible) {
                if let claim = repeatCalendarClaim { Button("Add another copy") { exportCalendar(claim, allowDuplicate: true); repeatCalendarClaim = nil } }
                Button("Cancel", role: .cancel) { repeatCalendarClaim = nil }
            } message: { Text("CareInOne cannot read your calendar to check whether the earlier copy is still there. Adding another may create a duplicate. If the time changed, update or remove the old copy in Calendar.") }
    }
    private func exportCalendar(_ claim: Claim, allowDuplicate: Bool = false) {
        guard addingToCalendar.insert(claim.id).inserted else { return }
        Task {
            defer { addingToCalendar.remove(claim.id) }
            do {
                let result = try await CalendarService.addAppointment(claim, state: store.state, isDemoWorkspace: store.isDemoWorkspace, allowDuplicate: allowDuplicate, stillEligible: { !store.isDemoWorkspace && AppointmentCalendarPolicy.canExport(claim, in: store.state) })
                store.notice = result == .added ? "Appointment added to your calendar. Check the saved time and duration. Edits here do not change the calendar copy." : "This appointment was already exported. No duplicate was created. Check the Calendar app; use Add another calendar copy only if you need another copy."
            } catch is CancellationError { store.notice = "Calendar save cancelled. No new event was added." }
            catch { store.error = error.localizedDescription }
        }
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
