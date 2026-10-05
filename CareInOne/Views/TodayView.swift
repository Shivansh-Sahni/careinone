import SwiftUI
import CareCore

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.careNavigate) private var navigate
    private var items: [PriorityItem] { PriorityEngine.items(store.state) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()).font(.caption.weight(.semibold)).tracking(1.3).foregroundStyle(.secondary)
                    Text(store.state.profile.displayName.isEmpty ? "Your care, connected." : "Hello, \(store.state.profile.displayName).").font(.largeTitle.bold())
                    Text("Less to keep in your head. More ready for what’s next.").font(.subheadline).foregroundStyle(.secondary)
                    if store.state.profile.demoLoaded { Badge(text: "Includes clearly labeled synthetic demo data") }
                }
                let summaryLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:10)) : AnyLayout(HStackLayout(spacing:10))
                summaryLayout {
                    metric("Changes", count: store.state.changes.filter { [.added, .changed, .superseded].contains($0.kind) }.count, symbol: "arrow.triangle.2.circlepath", route: .changes)
                    metric("Follow-through", count: store.state.loops.filter { [.open, .uncertain].contains($0.status) }.count, symbol: "checklist", route: .loops)
                    metric("To clarify", count: store.state.conflicts.filter { $0.status == .unresolved }.count, symbol: "text.bubble", route: .conflicts)
                }
                appointmentCard
                personalCheckBacks
                CareCard {
                    Label("A small update goes a long way", systemImage: "waveform.badge.plus").font(.headline)
                    Text("Save what you heard, read, or want to remember. We’ll connect it to what is already here.").font(.subheadline).foregroundStyle(.secondary)
                    Button { store.openAdd(.text) } label: { Label("Add an update", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                }
                let pending = store.state.sources.filter { [.needsReview, .pending, .failed, .cancelled].contains($0.state) }
                if !pending.isEmpty {
                    SectionHeading(title: "Ready when you are", subtitle: "Evidence is saved. Your review makes it part of My Care.")
                    ForEach(pending.prefix(3)) { source in NavigationLink(value: Route.source(source.id)) { CareCard { Label(source.title, systemImage: "doc.text.viewfinder").font(.headline); Text(source.state.displayLabel).font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain) }
                }
                section("Records to Clarify", destination: "discrepancies", route: .conflicts)
                section("Needs Follow-through", destination: "loops", route: .loops)
                section("What’s Next", destination: "prepare", route: .prepare(nil))
                section("What Changed", destination: "changes", route: .changes)
                if items.isEmpty { EmptyCard(title: "A starting point, not an all-clear", detail: "Nothing actionable has been identified in your saved information yet. Add a small update whenever you are ready.", symbol: "leaf") }
                SectionHeading(title: "Carry the context forward")
                NavigationLink(value: Route.intelligence) { CareCard { Label("Care connections", systemImage: "point.3.connected.trianglepath.dotted").font(.headline); Text("Trace evidence, explore the timeline, and track the information you share.").font(.subheadline).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                NavigationLink(value: Route.continuity) { CareCard { Label("Visit workspaces", systemImage: "rectangle.3.group").font(.headline); Text("Prepare, remember, and compare what changed.").font(.subheadline).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                HStack { NavigationLink(value: Route.prepare(nil)) { Label("Prepare", systemImage: "list.bullet.clipboard") }; Spacer(); NavigationLink(value: Route.brief) { Label("Care Brief", systemImage: "doc.richtext") } }.buttonStyle(.bordered)
                HStack { NavigationLink(value: Route.ask) { Label("Ask saved info", systemImage: "text.bubble") }; Spacer(); NavigationLink(value: Route.search) { Label("Search", systemImage: "magnifyingglass") } }.buttonStyle(.bordered)
            }.padding(20)
        }.background(Theme.background).navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
    }
    private func metric(_ label: String, count: Int, symbol: String, route: Route) -> some View {
        NavigationLink(value: route) { VStack(alignment: .leading, spacing: 10) { Image(systemName: symbol).foregroundStyle(Theme.accent); Text("\(count)").font(.title.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Theme.card, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
    }
    @ViewBuilder private func section(_ title: String, destination: String, route: Route) -> some View {
        let rows = items.filter { $0.destination == destination }
        if !rows.isEmpty {
            HStack { SectionHeading(title: title); NavigationLink("See all", value: route).font(.subheadline) }
            ForEach(rows.prefix(2)) { item in
                CareCard {
                    NavigationLink(value: destination == "loops" ? Route.followThroughHelp(item.id) : route) { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 6) { Text(item.title).font(.headline); Text(item.detail).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) } }.buttonStyle(.plain)
                    if destination == "loops" {
                        NavigationLink(value: Route.followThroughHelp(item.id)) { Label("Help me get this done", systemImage: "arrow.forward.circle.fill") }.font(.subheadline.weight(.semibold))
                    }
                    DisclosureGroup("Why this is shown") { Text(item.reason).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }.font(.caption)
                    if let source = item.sourceID { SourceLink(id: source) }
                }
            }
        }
    }
    private var appointmentCard: some View {
        let shortcut = PatientHome.appointment(store.state)
        return CareCard {
            Label("YOUR APPOINTMENT COMPANION", systemImage: "person.crop.rectangle.badge.plus").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(shortcut.title).font(.title2.bold())
            Text(shortcut.detail).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                companionBenefit("Know what to say", icon: "text.bubble")
                companionBenefit("Ask what matters", icon: "list.number")
                companionBenefit("Keep the answers", icon: "square.and.pencil")
            }.accessibilityElement(children: .combine)
            Button {
                if let id = shortcut.companionID { navigate(.visitCompanion(id)) }
                else if let id = store.startVisitCompanion(title: shortcut.appointmentTitle ?? "My next appointment", encounterID: shortcut.encounterID, eventAt: shortcut.appointmentAt) { navigate(.visitCompanion(id)) }
            } label: { Label(shortcut.action, systemImage: "arrow.right").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("today-companion")
            NavigationLink("All my appointment companions", value: Route.visitCompanions).font(.subheadline)
        }
    }
    private func companionBenefit(_ title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Image(systemName: icon).foregroundStyle(Theme.accent); Text(title).font(.caption.weight(.medium)).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var personalCheckBacks: some View {
        let plans = PatientHome.checkBacks(store.state)
        if !plans.isEmpty {
            SectionHeading(title: "You wanted to check back", subtitle: "Your personal reminders, separate from medical due dates.")
            ForEach(plans.prefix(3)) { plan in
                NavigationLink(value: Route.followThroughHelp(plan.loopID)) {
                    CareCard {
                        Label(store.state.loops.first { $0.id == plan.loopID }?.title ?? "Your next step", systemImage: "arrow.uturn.forward.circle").font(.headline)
                        Text(plan.nextAction.title).font(.subheadline).foregroundStyle(.secondary)
                        if let date = plan.checkBackAt { Text("You chose " + date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                        Text("Open my message and next step").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("today-checkback-" + plan.id.uuidString)
            }
        }
    }
}
