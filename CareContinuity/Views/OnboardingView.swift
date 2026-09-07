import SwiftUI
import CareCore

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var cloud = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Label("CARECONTINUITY", systemImage: "square.stack.3d.up.fill").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Theme.accent)
                Text("Keep the thread\nof your care.").font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text("Start with one visit, one note, or one thing coming up. Build a source-linked memory at your own pace.").font(.title3).foregroundStyle(.secondary)
                CareCard {
                    Label("On your iPhone", systemImage: "iphone.gen3").font(.headline)
                    Text("Your original sources and reviewed care information stay here. Local capture, OCR, review, search, and follow-through work without cloud analysis.").font(.subheadline)
                    TextField("Your first name (optional)", text: $name).textContentType(.givenName).textFieldStyle(.roundedBorder)
                    Toggle("Allow optional cloud analysis", isOn: $cloud)
                    Text("When enabled and a backend is configured, source text is sent for analysis. Your model provider may have its own retention policy. Proposals still need your review. You can turn this off anytime.").font(.caption).foregroundStyle(.secondary)
                }
                CareCard {
                    Label("Recording is always your choice", systemImage: "mic.badge.xmark").font(.headline)
                    Text("Ask everyone present for permission before recording. Each visit recording requires an explicit confirmation and microphone access. Keep your iPhone visible while it records.").font(.subheadline)
                }
                VStack(spacing: 12) {
                    startButton("Tell me about a recent visit", symbol: "waveform", mode: .voice)
                    startButton("Add something coming up", symbol: "calendar.badge.plus", mode: .manual)
                    startButton("Add a note, photo, or document", symbol: "doc.badge.plus", mode: .text)
                    Button { finish(); store.loadDemo() } label: { Label("Explore the synthetic demo", systemImage: "sparkles").frame(maxWidth: .infinity) }.buttonStyle(.bordered).accessibilityIdentifier("load-demo")
                    Button("Start with an empty care memory") { finish() }.font(.footnote)
                }
                Text("CareContinuity organizes what was reported. It does not verify medical correctness or choose between conflicting instructions.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.background(Theme.background)
    }
    private func startButton(_ title: String, symbol: String, mode: CaptureMode) -> some View { Button { finish(); store.openAdd(mode) } label: { Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 30) }.buttonStyle(.borderedProminent) }
    private func finish() { var profile = store.state.profile; profile.displayName = name; profile.cloudConsent = cloud; profile.cloudConsentAt = cloud ? Date() : nil; profile.onboarded = true; store.saveProfile(profile) }
}
