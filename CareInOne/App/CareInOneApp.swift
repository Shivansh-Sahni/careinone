import SwiftUI
import CareCore

@main struct CareInOneApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else if let startupError { ContentUnavailableView("Your records could not be opened", systemImage: "lock.doc", description: Text(startupError + "\nNo data has been reset. Unlock your device and reopen the app.")) }
                else { ProgressView("Opening your local care memory…").task { bootstrap() } }
            }
            .tint(Theme.accent)
        }
    }
    @MainActor private func bootstrap() {
        do {
            var override: URL?
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                override = FileManager.default.temporaryDirectory.appendingPathComponent("CareInOneUITests")
                if ProcessInfo.processInfo.arguments.contains("--reset") { try? FileManager.default.removeItem(at: override!) }
            }
            #endif
            let vault = try EvidenceVault(root: override)
            let repository = try SwiftDataRepository(root: vault.root)
            let store = try AppStore(repository: repository, vault: vault, clearBackendOnErase: override == nil, systemServicesEnabled: override == nil)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--refresh-demo") { store.removeDemo() }
            if ProcessInfo.processInfo.arguments.contains("--demo") { var profile = store.state.profile; profile.onboarded = true; if store.saveProfile(profile) { store.openDemo() } }
            #endif
            self.store = store
        } catch { startupError = error.localizedDescription }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var obscured = false
    var body: some View {
        @Bindable var store = store
        ZStack {
            Group {
                if store.showDemo && !store.isDemoWorkspace { Theme.background.ignoresSafeArea() }
                else if store.state.profile.appLock && !store.lock.unlocked { LockedView() }
                else if !store.state.profile.onboarded { OnboardingView() }
                else {
                    TabView(selection: $store.selectedTab) {
                        tab("Today", symbol: "square.grid.2x2", index: 0) { TodayView() }
                        tab("My Care", symbol: "heart.text.clipboard", index: 1) { MyCareView() }
                        tab("Visits", symbol: "calendar", index: 2) { VisitsView() }
                        tab("Sources", symbol: "tray.full", index: 3) { SourcesView() }
                        tab("Settings", symbol: "slider.horizontal.3", index: 4) { SettingsView() }
                    }
                }
            }
            if obscured { Theme.background.ignoresSafeArea().overlay { Label("CareInOne", systemImage: "lock.shield").font(.title2.weight(.semibold)) } }
        }
        .sheet(isPresented: Binding(get: { store.showAdd && (!store.state.profile.appLock || store.lock.unlocked) }, set: { store.showAdd = $0 })) { CaptureView(initialMode: store.captureMode).environment(store) }
        .fullScreenCover(isPresented: Binding(get: { store.showDemo && !store.isDemoWorkspace && (!store.state.profile.appLock || store.lock.unlocked) }, set: { store.showDemo = $0 }), onDismiss: { store.refreshNotifications(); store.lock.unlocked = !store.state.profile.appLock }) {
            DemoWorkspaceView(root: store.vault.root.appendingPathComponent("FictionalDemo", isDirectory: true))
        }
        .alert(store.error != nil ? "Could not complete that action" : "CareInOne", isPresented: Binding(get: { store.error != nil || store.notice != nil }, set: { if !$0 { store.error = nil; store.notice = nil } })) {
            Button("OK") { store.error = nil; store.notice = nil }
        } message: { Text(store.error ?? store.notice ?? "") }
        .onChange(of: scenePhase) { _, phase in
            obscured = phase != .active
            PrivacyShield.setVisible(phase != .active)
            if phase == .background && store.state.profile.appLock { store.lock.unlocked = false }
            if phase == .active { store.refreshNotifications() }
        }
        .onOpenURL { url in
            guard !store.showDemo || store.isDemoWorkspace else { return }
            store.importedURL = url; store.openAdd(.file)
        }
    }
    private func tab<Content: View>(_ title: String, symbol: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        CareNavigationStack {
            content().toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.openAdd() } label: { Image(systemName: "plus.circle.fill").font(.title2) }.accessibilityLabel("Add care information").accessibilityIdentifier("global-add")
                }
            }
        }.tabItem { Label(title, systemImage: symbol) }.tag(index)
    }
}
struct LockedView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield").font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text("Your care, kept close").font(.largeTitle.bold())
            Text("Unlock to open your saved information.").foregroundStyle(.secondary)
            Button("Unlock CareInOne") { Task { _ = await store.lock.authenticate() } }.buttonStyle(.borderedProminent).disabled(store.lock.authenticating)
            if !store.lock.message.isEmpty { Text(store.lock.message).font(.footnote).foregroundStyle(.secondary) }
        }.padding(30)
    }
}
