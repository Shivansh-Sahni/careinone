import SwiftUI
import CareCore

enum Theme {
    static let accent = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red:0.35,green:0.82,blue:0.74,alpha:1) : UIColor(red:0.05,green:0.43,blue:0.40,alpha:1) })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let warning = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red:1,green:0.72,blue:0.40,alpha:1) : UIColor(red:0.65,green:0.35,blue:0.10,alpha:1) })
}
struct CareCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 20)).overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.04)) } }
}
struct Badge: View {
    let text: String; var caution = false
    var body: some View { Text(text).font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 5).foregroundStyle(caution ? Theme.warning : Theme.accent).background((caution ? Theme.warning : Theme.accent).opacity(0.10), in: RoundedRectangle(cornerRadius:12)) }
}
struct SectionHeading: View {
    let title: String; var subtitle: String? = nil
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.title3.bold()); if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct SourceLink: View {
    @Environment(AppStore.self) private var store
    let id: UUID
    var body: some View { if let source = store.source(id) { NavigationLink(value: Route.source(id)) { Label(source.title, systemImage: "doc.text.magnifyingglass").font(.subheadline).multilineTextAlignment(.leading) }.buttonStyle(.plain).foregroundStyle(Theme.accent) } }
}
struct ClaimSummary: View {
    let claim: Claim
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(claim.summary).font(.headline)
            let badgeLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading)) : AnyLayout(HStackLayout())
            badgeLayout { Badge(text: claim.certainty.displayLabel, caution: [.uncertain, .conditional, .disputed].contains(claim.certainty)); if claim.provenance == .patientReported { Badge(text: "Patient reported") } }
            Text(claim.action.displayLabel + " · " + (claim.eventAt?.formatted(date: .abbreviated, time: .omitted) ?? "Event date unknown")).font(.caption).foregroundStyle(.secondary)
        }
    }
}
enum Route: Hashable {
    case source(UUID), entity(UUID), category(EntityKind), changes, conflicts, loops, prepare(UUID?), ask, search, questions(UUID?), brief, network, trends
}
struct CareDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            switch route {
            case .source(let id): SourceDetailView(id: id)
            case .entity(let id): EntityDetailView(id: id)
            case .category(let kind): CategoryView(kind: kind)
            case .changes: ChangesView()
            case .conflicts: ConflictsView()
            case .loops: LoopsView()
            case .prepare(let id): PrepareView(encounterID: id)
            case .ask: AskView()
            case .search: SearchView()
            case .questions(let id): QuestionsView(entityID: id)
            case .brief: CareBriefView()
            case .network: CareNetworkView()
            case .trends: TrendsView()
            }
        }
    }
}
extension View { func careDestinations() -> some View { modifier(CareDestinations()) } }
struct EmptyCard: View {
    let title: String; let detail: String; var symbol = "tray"
    var body: some View { CareCard { Label(title, systemImage: symbol).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) } }
}
struct OptionalDateField: View {
    let title: String; @Binding var date: Date?; var time = false
    var body: some View {
        Toggle(title + " is known", isOn: Binding(get: { date != nil }, set: { date = $0 ? Date() : nil }))
        if date != nil { DatePicker(title, selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: time ? [.date, .hourAndMinute] : [.date]) }
    }
}
