import SwiftUI
import CareCore

/// A separate database and evidence directory keep fiction out of personal care.
struct DemoWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let root: URL
    @State private var store: AppStore?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Label(dynamicTypeSize.isAccessibilitySize ? "Demo" : "Fictional demo", systemImage: "sparkles")
                        .font(.headline)
                        .accessibilityLabel("Fictional practice demo. Personal care records are separate.")
                    Spacer()
                    Button(dynamicTypeSize.isAccessibilitySize ? "Exit" : "Return to my care") { store?.cancelAllAnalysis(); dismiss() }
                        .font(.subheadline.weight(.semibold)).accessibilityLabel("Return to my care").accessibilityIdentifier("exit-demo")
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("Only enter fictional practice information here. Your personal records are kept separately.")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(14).background(Theme.accent.opacity(0.10))
            if let store { RootView().environment(store) }
            else if let error {
                ContentUnavailableView("The demo could not be opened", systemImage: "doc.badge.ellipsis", description: Text(error + " Your personal records were preserved."))
            } else { ProgressView("Opening fictional demo…").frame(maxWidth: .infinity, maxHeight: .infinity).task { open() } }
        }.tint(Theme.accent).interactiveDismissDisabled()
            .onDisappear { store?.cancelAllAnalysis() }
    }
    @MainActor private func open() {
        do {
            let vault = try EvidenceVault(root: root)
            let value = try AppStore(repository: SwiftDataRepository(root: root), vault: vault, isDemoWorkspace: true, systemServicesEnabled: false)
            if !value.state.profile.demoLoaded {
                guard value.mutate({ state in try SyntheticDemo.load(into: &state); state.profile.onboarded = true }) else {
                    throw CareError.invalid("The fictional records could not be saved.")
                }
            }
            store = value
        } catch { self.error = "Try opening the demo again while this device is unlocked." }
    }
}
