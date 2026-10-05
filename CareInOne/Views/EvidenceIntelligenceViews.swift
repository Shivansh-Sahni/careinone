import SwiftUI
import CareCore

struct EvidenceIntelligenceView: View {
    var body: some View {
        List {
            Section {
                Text("See how your information connects").font(.title2.bold())
                Text("Trace the evidence behind your care, understand when it became known here, and keep the copies you carry into visits up to date.").foregroundStyle(.secondary)
            }
            Section {
                NavigationLink(value: Route.evidenceMap(nil)) {
                    Label { VStack(alignment: .leading, spacing: 5) { Text("Evidence map").font(.headline); Text("From original source to reviewed report and follow-through").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "point.3.connected.trianglepath.dotted") }
                }.accessibilityIdentifier("intelligence-map")
                NavigationLink(value: Route.evidenceTimeline(nil)) {
                    Label { VStack(alignment: .leading, spacing: 5) { Text("Two-date timeline").font(.headline); Text("Medical dates and when information was added here").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "calendar.badge.clock") }
                }.accessibilityIdentifier("intelligence-timeline")
                NavigationLink(value: Route.handoffs) {
                    Label { VStack(alignment: .leading, spacing: 5) { Text("Tracked handoffs").font(.headline); Text("Selected copies, later changes, and replies to review").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "arrow.up.doc.on.clipboard") }
                }.accessibilityIdentifier("intelligence-handoffs")
            }
            Section("Explore your saved evidence") {
                NavigationLink(value: Route.sourceOmission) { Label("Leave sources out · temporary preview", systemImage: "square.stack.3d.up.slash") }.accessibilityIdentifier("intelligence-omission")
                Text("Explore information dependencies. These tools do not simulate treatment or decide which medical report is correct.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Care connections").navigationBarTitleDisplayMode(.inline)
    }
}

struct EvidenceMapView: View {
    @Environment(AppStore.self) private var store
    let focus: EvidenceNodeID?
    @State private var search = ""
    @State private var browseSources = false
    var body: some View {
        Group {
            if let focus { EvidenceTraceView(focus: focus, graph: EvidenceGraph(store.state)) }
            else {
                List {
                    Section {
                        Text("Choose an item to trace its supporting reports, original sources, and connected work.")
                        Text("Arrows represent saved information relationships, not medical causality or confidence.").font(.caption).foregroundStyle(.secondary)
                        Picker("Start from", selection: $browseSources) { Text("Care items").tag(false); Text("Sources").tag(true) }.pickerStyle(.segmented)
                    }
                    if browseSources {
                        ForEach(store.state.sources.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }) { source in
                            NavigationLink(value: Route.evidenceMap(.source(source.id))) { Label(source.title, systemImage: "doc.text") }
                        }
                    } else {
                        ForEach(store.state.entities.filter { search.isEmpty || $0.label.localizedCaseInsensitiveContains(search) }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }) { entity in
                            NavigationLink(value: Route.evidenceMap(.entity(entity.id))) { Label(entity.label, systemImage: entity.kind.symbol) }.accessibilityIdentifier("map-entity-" + entity.label)
                        }
                    }
                    if store.state.sources.isEmpty { Text("Capture any small update to begin. Your medical history does not need to be complete.").foregroundStyle(.secondary) }
                }.searchable(text: $search, prompt: "Find a starting point")
            }
        }.navigationTitle(focus == nil ? "Evidence map" : "Evidence trace").navigationBarTitleDisplayMode(.inline)
    }
}
private struct EvidenceTraceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let focus: EvidenceNodeID
    let graph: EvidenceGraph
    @State private var direction: EvidenceDirection
    init(focus: EvidenceNodeID, graph: EvidenceGraph) {
        self.focus = focus; self.graph = graph
        if case .source = focus { _direction = State(initialValue: .downstream) }
        else { _direction = State(initialValue: .upstream) }
    }
    var body: some View {
        let trace = graph.trace(from: focus, direction: direction)
        List {
            if let root = graph.nodes[focus] {
                Section {
                    Text(root.title).font(.title2.bold())
                    Badge(text: root.id.label)
                    if dynamicTypeSize.isAccessibilitySize { directionPicker.pickerStyle(.menu) }
                    else { directionPicker.pickerStyle(.segmented) }
                    Text("Follow the connections between reviewed reports and their evidence. A source with pending review may have no outgoing connection yet.").font(.caption).foregroundStyle(.secondary)
                    if case .entity(let id) = focus { NavigationLink("Open this care item", value: Route.entity(id)) }
                    if case .source(let id) = focus { SourceLink(id: id) }
                }
                ForEach(trace.steps.filter { $0.depth > 0 }) { step in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Step \(step.depth) · " + step.node.id.label).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                            if let parent = step.parent, let label = step.relationship {
                                Text(direction == .upstream ? "\(step.node.title) → \(label) → \(graph.nodes[parent]?.title ?? "previous item")" : "\(graph.nodes[parent]?.title ?? "previous item") → \(label) → \(step.node.title)").font(.caption).foregroundStyle(.secondary)
                            }
                            NavigationLink(step.node.title, value: Route.evidenceMap(step.id)).font(.headline)
                            DisclosureGroup("Evidence and status") { Text(step.node.detail).font(.subheadline).textSelection(.enabled) }
                            ForEach(step.node.sourceIDs, id: \.self) { SourceLink(id: $0) }
                        }.padding(.vertical, 4)
                    }
                }
                if trace.steps.count == 1 { Text("No connected items in this direction have been saved here. This does not describe care outside the app.").foregroundStyle(.secondary) }
                if trace.truncated { Text("Showing up to 200 items across six steps. Open a connected item to continue tracing.").foregroundStyle(Theme.warning) }
            } else { ContentUnavailableView("This connection is no longer saved", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
        }
    }
    private var directionPicker: some View {
        Picker("Trace", selection: $direction) { ForEach(EvidenceDirection.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
    }
}

struct EvidenceTimelineView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entityID: UUID?
    @State private var axis = TimelineDateAxis.event
    @State private var reportsOnly = false
    @State private var search = ""
    private var entries: [TimelineEntry] {
        EvidenceTimeline.entries(store.state, entityID: entityID, axis: axis, reportsOnly: reportsOnly).filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        let all = entries, dated = all.filter { $0.date(on: axis) != nil }, unknown = all.filter { $0.date(on: axis) == nil }
        List {
            Section {
                Text("The event and the evidence can arrive at different times").font(.headline)
                Picker("Order by", selection: $axis) { ForEach(TimelineDateAxis.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("timeline-axis")
                Toggle("Reviewed reports only", isOn: $reportsOnly)
                Text("Current reviewed versions are shown. Added here means source capture; reviewed here means acceptance of the current report version. Neither verifies the medical event. Unknown dates stay unknown.").font(.caption).foregroundStyle(.secondary)
            }
            Section(axis.rawValue + " · newest first") {
                ForEach(dated) { row($0) }
                if dated.isEmpty { Text("No known dates in this view.").foregroundStyle(.secondary) }
            }
            if !unknown.isEmpty {
                Section("\(axis.rawValue) not provided · \(unknown.count)") { ForEach(unknown) { row($0) } }
            }
        }.navigationTitle("Two-date timeline").navigationBarTitleDisplayMode(.inline).searchable(text: $search, prompt: "Filter saved information")
    }
    private func row(_ entry: TimelineEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date(on: axis)?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(entry.title).font(.headline)
            Text(entry.detail).font(.caption).foregroundStyle(.secondary)
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                VStack(alignment: .leading, spacing: 4) { Text("Medical event").font(.caption); Text(entry.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown").font(.subheadline) }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                VStack(alignment: .leading, spacing: 4) { Text("Added here").font(.caption); Text(entry.capturedAt.formatted(date: .abbreviated, time: .omitted)).font(.subheadline) }
            }.accessibilityElement(children: .combine)
            if let effective = entry.effectiveAt { Text("Effective: " + effective.formatted(date: .abbreviated, time: .omitted)).font(.caption) }
            if let reviewed = entry.reviewedAt { Text("Reviewed here: " + reviewed.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
            if let days = entry.daysAddedAfterEvent() { Text("Added \(days) day(s) after the reported event. This is a record arrival gap, not a delay in care.").font(.caption).foregroundStyle(.secondary) }
            SourceLink(id: entry.sourceID)
            NavigationLink("Trace this evidence", value: Route.evidenceMap(entry.id)).font(.caption)
        }.padding(.vertical, 6)
    }
}

struct SourceOmissionView: View {
    @Environment(AppStore.self) private var store
    @State private var selected: Set<UUID> = []
    @State private var result: SourceOmissionPreview?
    @State private var failure: String?
    @State private var task: Task<Void, Never>?
    @State private var running = false
    var body: some View {
        List {
            Section {
                Text("What relies on these sources?").font(.title2.bold())
                Text("Temporarily leave out selected evidence and recompute the saved-care view. Your actual sources, reviewed reports and tasks stay untouched.")
                Text("A discrepancy disappearing in this preview does not mean it was medically resolved. This does not simulate changing or stopping treatment.").font(.caption).foregroundStyle(.secondary)
                Button(running ? "Computing locally…" : "Preview without selected sources", systemImage: "eye") { preview() }.disabled(selected.isEmpty || running).accessibilityIdentifier("omission-preview")
                if running { Button("Cancel preview") { task?.cancel(); running = false } }
                if let failure { Text(failure).foregroundStyle(Theme.warning) }
                if result != nil { Button("Clear temporary preview") { result = nil; selected.removeAll() } }
            }
            if let result {
                Section("Temporary result · nothing was saved") {
                    Text("\(result.omittedSourceIDs.count) sources left out").font(.headline).accessibilityIdentifier("omission-result")
                    if !result.careItemsWithoutReports.isEmpty {
                        Text("These items would have no reviewed reports left here: " + result.careItemsWithoutReports.map(\.label).joined(separator: ", "))
                        Text("This means no remaining evidence in this preview, not absence of the condition, medicine or care.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ComparisonSections(comparison: result.comparison)
            }
            Section("Choose up to 30 sources · \(selected.count) selected") {
                ForEach(store.state.sources.sorted { $0.capturedAt > $1.capturedAt }) { source in
                    Toggle(source.title, isOn: Binding(get: { selected.contains(source.id) }, set: { checked in
                        if checked && selected.count < 30 { selected.insert(source.id) } else { selected.remove(source.id) }
                    })).disabled(!selected.contains(source.id) && selected.count >= 30).accessibilityIdentifier("omission-source-" + source.title)
                }
                if store.state.sources.isEmpty { Text("Add evidence before exploring its connections.") }
            }
        }.navigationTitle("Leave sources out").navigationBarTitleDisplayMode(.inline)
            .onChange(of: selected) { _, _ in task?.cancel(); running = false; result = nil; failure = nil }
            .onChange(of: store.state) { _, _ in task?.cancel(); running = false; result = nil; selected.formIntersection(Set(store.state.sources.map(\.id))) }
            .onDisappear { task?.cancel(); running = false }
    }
    private func preview() {
        task?.cancel(); failure = nil; running = true
        let state = store.state, selection = selected
        task = Task {
            let worker = Task.detached(priority: .userInitiated) { try SourceOmissionEngine.preview(selection, in: state) }
            do {
                let value = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                guard store.state == state, selected == selection else { running = false; return }
                result = value; running = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { failure = error.localizedDescription; running = false } }
        }
    }
}
