import SwiftUI
import CareCore

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var items: [PriorityItem] { PriorityEngine.items(store.state) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()).font(.caption.weight(.semibold)).tracking(1.3).foregroundStyle(.secondary)
                    Text(store.state.profile.displayName.isEmpty ? "Your care, connected." : "Hello, \(store.state.profile.displayName).").font(.largeTitle.bold())
                    Text("What changed. What needs a next step.").font(.subheadline).foregroundStyle(.secondary)
                    if store.state.profile.demoLoaded { Badge(text: "Includes clearly labeled synthetic demo data") }
                }
                let summaryLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing:10)) : AnyLayout(HStackLayout(spacing:10))
                summaryLayout {
                    metric("Changes", count: store.state.changes.filter { [.added, .changed, .superseded].contains($0.kind) }.count, symbol: "arrow.triangle.2.circlepath", route: .changes)
                    metric("Follow-through", count: store.state.loops.filter { [.open, .uncertain].contains($0.status) }.count, symbol: "checklist", route: .loops)
                    metric("To clarify", count: store.state.conflicts.filter { $0.status == .unresolved }.count, symbol: "text.bubble", route: .conflicts)
                }
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
                    NavigationLink(value: route) { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 6) { Text(item.title).font(.headline); Text(item.detail).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) } }.buttonStyle(.plain)
                    DisclosureGroup("Why this is shown") { Text(item.reason).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }.font(.caption)
                    if let source = item.sourceID { SourceLink(id: source) }
                }
            }
        }
    }
}
