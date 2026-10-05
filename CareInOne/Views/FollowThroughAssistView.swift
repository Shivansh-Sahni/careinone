import SwiftUI
import CareCore

struct FollowThroughAssistView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let loopID: String
    @State private var plan: FollowThroughPlan?
    @State private var autosave: Task<Void, Never>?
    @State private var copied = false
    @State private var regenerate = false
    @State private var completing = false
    @State private var deleting = false
    @State private var savingStatus = "Saved on this device"
    @State private var section = 0
    @State private var pendingObstacle: FollowThroughObstacle?
    @State private var lastSavedPlan: FollowThroughPlan?
    @State private var autosavePaused = false
    @State private var hasOpenedPlan = false
    @State private var wasRemoved = false
    @State private var discardingEdits = false
    @State private var activeLoopID: String?
    @State private var relinkTarget = ""
    @FocusState private var editing: Bool
    private var currentLoopID: String { activeLoopID ?? loopID }
    private var loop: CareLoop? { store.state.loops.first { $0.id == currentLoopID } }
    private var storedPlan: FollowThroughPlan? { FollowThroughAssistEngine.plan(for: currentLoopID, in: store.state) }

    var body: some View {
        Group {
            if let plan, storedPlan?.id == plan.id {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(loop?.title ?? plan.savedTitle ?? "My saved next step").font(.largeTitle.bold()).accessibilityIdentifier("assist-title")
                            if let loop {
                                Text(FollowThroughAssistEngine.nextStepExplanation(for: loop)).foregroundStyle(.secondary)
                                HStack { Badge(text: loop.status == .completed ? "Completed in saved care" : "One small step at a time"); Spacer() }
                            } else { Badge(text: "Paused while saved evidence changes", caution: true) }
                            if plan.supportingSourceIDs.contains(where: { store.source($0)?.synthetic == true }) { Badge(text: "Contains synthetic demo information", caution: true) }
                        }
                        if autosavePaused { saveRecoveryBanner }
                        if loop == nil { pausedPlanCard(plan) }
                        Picker("Helper section", selection: $section) {
                            Text("My next step").tag(0)
                            Text("Replies & progress").tag(1)
                        }.pickerStyle(.segmented).accessibilityIdentifier("assist-section")
                        if section == 0 {
                            if loop != nil { obstacleCard(plan) }
                            messageCard(plan)
                            nextStepCard(plan)
                        } else {
                            replyCard(plan)
                            progressCard(plan)
                            evidenceCard(loop, plan)
                        }
                        Text(savingStatus).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("assist-save-status")
                        if let loop, loop.status != .completed {
                            Button("I've completed this care task", systemImage: "checkmark.circle") { completing = true }.accessibilityIdentifier("assist-complete")
                            Text("Reaching out, sending a message, and saving a reply do not mark the care task complete.").font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Remove this helper plan", role: .destructive) { deleting = true }.font(.footnote)
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively).background(Theme.background)
            } else if wasRemoved {
                ContentUnavailableView {
                    Label("This helper plan was removed", systemImage: "doc.badge.minus")
                } description: {
                    Text("Its copied messages and drafts are no longer available. You can start a new plan from the evidence that is still saved.")
                } actions: {
                    if loop != nil { Button("Start a new helper plan") { hasOpenedPlan = false; wasRemoved = false; loadOrCreate() }.accessibilityIdentifier("assist-start-new") }
                }.accessibilityIdentifier("assist-removed")
            } else if loop == nil {
                ContentUnavailableView("This item is no longer here", systemImage: "checklist", description: Text("Its saved evidence may have changed. Open Follow-through to see the current items."))
            } else {
                ContentUnavailableView("Prepare your next step", systemImage: "hand.wave", description: Text("Your helper plan could not be opened. Your saved care is unchanged."))
                    .overlay(alignment: .bottom) { Button("Try again") { loadOrCreate() }.padding() }
            }
        }
        .navigationTitle("Help me get this done").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button { editing = false; if persist() { dismiss() } } label: { Label("Back", systemImage: "chevron.left") }.accessibilityIdentifier("assist-back") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done editing text") { editing = false; _ = persist() }.accessibilityIdentifier("assist-editing-done") }
        }
        .onAppear { loadOrCreate() }
        .onChange(of: plan) { _, updated in
            guard let updated, storedPlan?.id == updated.id, storedPlan != updated else { return }
            store.followThroughRecoveryDrafts[updated.id] = updated
            guard !autosavePaused else { return }
            autosave?.cancel(); savingStatus = "Saving your draft…"
            autosave = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation() } catch { return }
                _ = persist()
            }
        }
        .onChange(of: storedPlan) { _, updated in reconcileStoredPlan(updated) }
        .onDisappear { autosave?.cancel(); _ = persist() }
        .onChange(of: section) { _, _ in autosave?.cancel(); _ = persist() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { autosave?.cancel(); _ = persist() } }
        .confirmationDialog("Replace your message draft?", isPresented: $regenerate, titleVisibility: .visible) {
            Button("Create a fresh message") {
                if let pendingObstacle { self.plan?.obstacle = pendingObstacle }
                pendingObstacle = nil
                guard let plan, persist(), store.refreshFollowThroughMessage(plan.id) else { return }; reload()
            }
            Button("Keep my draft", role: .cancel) { pendingObstacle = nil }
        } message: { Text("This uses the selected situation and your current saved evidence. Your edits to this message will be replaced.") }
        .confirmationDialog("Mark this care task completed by your report?", isPresented: $completing, titleVisibility: .visible) {
            Button("Yes, I completed it") {
                guard let loop, persist() else { return }
                if store.setLoop(loop, status: .completed, note: loop.note, due: loop.dueAt, precision: loop.precision, dateEdited: store.state.loopOverrides[loop.id]?.dateEdited ?? false) { reload() }
            }
        } message: { Text("This records your report of completion. It does not create a result, confirm clinician verification, or settle conflicting instructions.") }
        .confirmationDialog("Remove the helper plan?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Remove plan", role: .destructive) {
                guard let plan else { return }; autosave?.cancel()
                if store.mutate({ FollowThroughAssistEngine.remove(plan.id, from: &$0) }) { self.plan = nil; store.refreshNotifications(); dismiss() }
            }
        } message: { Text("Its message, reply draft, personal reminder, and contact history will be removed. Saved source replies and the care task remain.") }
        .confirmationDialog("Discard edits that have not been saved?", isPresented: $discardingEdits, titleVisibility: .visible) {
            Button("Discard unsaved edits", role: .destructive) { if let plan { store.followThroughRecoveryDrafts[plan.id] = nil }; reload() }
        } message: { Text("The last successfully saved version stays on your device.") }
    }

    private var saveRecoveryBanner: some View {
        CareCard {
            Label("Your latest edits haven't saved", systemImage: "exclamationmark.circle").font(.headline).foregroundStyle(Theme.warning)
            Text("Automatic saving is paused. Your edits are kept while this app stays open, including if you change tabs. Only a successful save protects them after the app closes.").font(.subheadline)
            Button("Retry save") { _ = persist(retry: true) }.buttonStyle(.borderedProminent).accessibilityIdentifier("assist-retry-save")
            Button("Discard unsaved edits", role: .destructive) { discardingEdits = true }.accessibilityIdentifier("assist-discard-edits")
        }.accessibilityIdentifier("assist-save-failure")
    }
    private func pausedPlanCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label("Your drafts and progress are safe", systemImage: "pause.circle").font(.headline)
            Text("The source evidence changed, so its earlier care task is no longer in the current list. Review the saved sources below. Your actual replies, contact history, and unfinished drafts stay here.").font(.subheadline)
            Text("Care completion and check-back notifications are paused. Reconnect this helper only if a reviewed task represents the same next step.").font(.caption).foregroundStyle(.secondary)
            ForEach(plan.supportingSourceIDs, id: \.self) { SourceLink(id: $0) }
            let occupied = Set((store.state.followThroughPlans?.plans ?? []).filter { $0.id != plan.id }.map(\.loopID))
            let choices = store.state.loops.filter { !occupied.contains($0.id) }.sorted { $0.title < $1.title }
            if !choices.isEmpty {
                Picker("Connect to current care task", selection: $relinkTarget) {
                    Text("Choose the matching task").tag("")
                    ForEach(choices) { item in Text(item.title + " · " + item.stage.rawValue).tag(item.id) }
                }.accessibilityIdentifier("assist-relink-picker")
                Button("Reconnect this helper") {
                    guard !relinkTarget.isEmpty, persist() else { return }
                    let selected = relinkTarget
                    if store.mutate({ try FollowThroughAssistEngine.relink(plan.id, toLoopID: selected, in: &$0) }) {
                        activeLoopID = selected; store.followThroughRecoveryDrafts[plan.id] = nil; reload(); store.refreshNotifications()
                    }
                }.disabled(relinkTarget.isEmpty).accessibilityIdentifier("assist-relink")
            } else { Text("After reviewing your sources, any current care tasks will be available here to connect.").font(.caption).foregroundStyle(.secondary) }
        }.accessibilityIdentifier("assist-paused")
    }

    private func obstacleCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Text("What's getting in the way?").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(FollowThroughObstacle.allCases) { obstacle in
                    Button { chooseObstacle(obstacle) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: obstacle.symbol).font(.title3)
                            Text(obstacle.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                        }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(12)
                            .background(plan.obstacle == obstacle ? Theme.accent.opacity(0.13) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(plan.obstacle == obstacle ? Theme.accent : Color.clear, lineWidth: 1.5))
                    }.buttonStyle(.plain).foregroundStyle(plan.obstacle == obstacle ? Theme.accent : Color.primary)
                        .accessibilityAddTraits(plan.obstacle == obstacle ? .isSelected : [])
                        .accessibilityIdentifier("assist-obstacle-" + obstacle.rawValue)
                }
            }
        }
    }
    private func messageCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label(loop == nil ? "Your saved message draft" : "The words are ready", systemImage: "text.bubble").font(.headline)
            Text(loop == nil ? "This draft was written before the source changed. Review the saved evidence before using it." : "Read this during a call or edit it for your patient portal.").font(.subheadline).foregroundStyle(.secondary)
            TextField("Office or person (optional)", text: binding(\.recipient, fallback: "")).textFieldStyle(.roundedBorder).accessibilityIdentifier("assist-recipient")
                .focused($editing)
            if loop != nil { Button("Update message for my situation", systemImage: "arrow.clockwise") { pendingObstacle = nil; regenerate = true }.font(.subheadline).accessibilityIdentifier("assist-regenerate") }
            if FollowThroughAssistEngine.savedInformationChanged(plan, in: store.state) {
                Label("Your saved information changed. Review or refresh this draft before using it.", systemImage: "info.circle").font(.caption).foregroundStyle(Theme.warning)
            }
            EvidenceTextEditor(text: binding(\.messageDraft, fallback: ""), identifier: "assist-message", placeholder: "Your message draft", minimumHeight: 210, maximumCharacters: 20_000, accessibilityName: "Message draft")
                .padding(6).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            Text("\(plan.messageDraft.count.formatted()) / 20,000 characters").font(.caption).foregroundStyle(plan.messageDraft.count > 20_000 ? Theme.warning : .secondary)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 20))) {
                Button(copied ? "Copied" : "Copy message", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    guard persist() else { return }; UIPasteboard.general.setItems([["public.utf8-plain-text": plan.messageDraft]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(300)])
                    copied = true
                }.disabled(plan.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("assist-copy")
                ShareLink(item: plan.messageDraft) { Label("Share", systemImage: "square.and.arrow.up") }.disabled(plan.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("assist-share")
            }.font(.subheadline)
            Text("Sharing opens your choices; it does not record delivery. Mark that you reached out only after you do.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func nextStepCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label("My next small step", systemImage: "figure.walk").font(.headline)
            Picker("I'll", selection: binding(\.nextAction, fallback: .message)) { ForEach(FollowThroughAction.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).accessibilityIdentifier("assist-next-action")
            Toggle("Choose a personal check-back time", isOn: Binding(get: { self.plan?.checkBackAt != nil }, set: { enabled in self.plan?.checkBackAt = enabled ? Calendar.current.date(byAdding: .day, value: 1, to: Date()) : nil })).accessibilityIdentifier("assist-checkback-toggle")
            if plan.checkBackAt != nil {
                DatePicker("My check-back time", selection: Binding(get: { self.plan?.checkBackAt ?? Date() }, set: { self.plan?.checkBackAt = $0 }), displayedComponents: [.date, .hourAndMinute]).accessibilityIdentifier("assist-checkback-date")
            }
            Text("This is your personal check-back time. It does not change the timing in your saved care instructions.").font(.caption).foregroundStyle(.secondary)
            if let checkBackAt = plan.checkBackAt, checkBackAt <= Date() {
                Text("Your chosen check-back time has arrived. Move it whenever it works for you.").font(.subheadline).foregroundStyle(Theme.accent)
            }
            if loop == nil {
                Text("Your check-back time is kept here. Notifications can resume after you reconnect this helper to an open task.").font(.caption).foregroundStyle(.secondary)
            } else if store.state.profile.notifications && store.state.profile.notifyTasks {
                Text("Future check-back times can remind you with a private, generic notification.").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Enable private reminders in Settings") { _ = persist(); store.selectedTab = 4 }.font(.caption)
            }
        }
    }
    private func progressCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label("Keep my place", systemImage: "checklist").font(.headline)
            TextField("A note for next time (optional)", text: binding(\.attemptDraft, fallback: ""), axis: .vertical).textFieldStyle(.roundedBorder).accessibilityIdentifier("assist-attempt-note")
                .focused($editing)
            Text("Notes can contain up to 2,000 characters.").font(.caption).foregroundStyle(.secondary)
            ForEach(FollowThroughAttemptKind.allCases.filter { $0 != .replySaved }) { kind in
                Button(kind.title) {
                    guard persist(), store.recordFollowThroughAttempt(plan.id, kind: kind, note: plan.attemptDraft) else { return }
                    editing = false; reload()
                }.accessibilityIdentifier("assist-record-" + kind.rawValue)
            }
            if !plan.history.isEmpty {
                Divider()
                ForEach(plan.history.reversed()) { attempt in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(attempt.kind.title).font(.subheadline.weight(.medium))
                        Text(attempt.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        if !attempt.note.isEmpty { Text(attempt.note).font(.subheadline) }
                    }.padding(.vertical, 3)
                }
            }
        }
    }
    private func replyCard(_ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label("What came back?", systemImage: "arrowshape.turn.up.left").font(.headline)
            Text("Paste the reply or write what you remember hearing. It will be saved as evidence for you to review.").font(.subheadline).foregroundStyle(.secondary)
            EvidenceTextEditor(text: binding(\.replyDraft, fallback: ""), identifier: "assist-reply-draft", placeholder: "Paste or write the reply", minimumHeight: 115, maximumCharacters: 20_000, accessibilityName: "Reply draft")
                .padding(6).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            Text("\(plan.replyDraft.count.formatted()) / 20,000 characters").font(.caption).foregroundStyle(plan.replyDraft.count > 20_000 ? Theme.warning : .secondary)
            OptionalDateField(title: "Reply date", date: binding(\.replyEventAt, fallback: nil))
            Toggle("This reply is synthetic demo information", isOn: binding(\.replySynthetic, fallback: false)).font(.caption)
            Button("Save reply & review", systemImage: "doc.badge.plus") {
                guard persist(), let id = store.captureFollowThroughReply(plan.replyDraft, eventAt: plan.replyEventAt, planID: plan.id, synthetic: plan.replySynthetic) else { return }
                reload(); navigate(.source(id))
            }.buttonStyle(.borderedProminent).disabled(plan.replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("assist-save-reply")
            Text(autosavePaused ? "This draft is waiting for a successful save. Retry saving before closing the app." : "Drafts save automatically. A reply does not automatically complete the task or confirm which instruction is correct.").font(.caption).foregroundStyle(.secondary)
            ForEach(plan.replySourceIDs, id: \.self) { SourceLink(id: $0) }
        }
    }
    private func evidenceCard(_ loop: CareLoop?, _ plan: FollowThroughPlan) -> some View {
        CareCard {
            Label("Why this is in my care", systemImage: "doc.text.magnifyingglass").font(.headline)
            if let loop { Text(loop.timing()).font(.subheadline) }
            ForEach(plan.supportingSourceIDs, id: \.self) { SourceLink(id: $0) }
            if let loop { NavigationLink(value: Route.entity(loop.entityID)) { Label("See the full care history", systemImage: "clock.arrow.circlepath") }.font(.subheadline) }
        }
    }
    private func binding<Value>(_ path: WritableKeyPath<FollowThroughPlan, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { plan?[keyPath: path] ?? fallback }, set: { plan?[keyPath: path] = $0; copied = false })
    }
    private func chooseObstacle(_ obstacle: FollowThroughObstacle) {
        guard let plan, plan.obstacle != obstacle else { return }
        let generated = try? FollowThroughAssistEngine.message(for: currentLoopID, obstacle: plan.obstacle, recipient: plan.recipient, in: store.state)
        if generated == plan.messageDraft {
            self.plan?.obstacle = obstacle
            if persist(), store.refreshFollowThroughMessage(plan.id) { reload() }
        } else { pendingObstacle = obstacle; regenerate = true }
    }
    private func loadOrCreate() {
        if let stored = storedPlan {
            if let recovery = store.followThroughRecoveryDrafts[stored.id], let recovered = FollowThroughAssistEngine.rebaseEditableDraft(recovery, baseline: nil, onto: stored) {
                plan = recovered; lastSavedPlan = stored; autosavePaused = recovered != stored
                savingStatus = autosavePaused ? "Unsaved edits recovered. Retry saving when ready." : "Saved on this device"
            } else { reconcileStoredPlan(stored) }
            hasOpenedPlan = true; wasRemoved = false
        } else if hasOpenedPlan || plan != nil { invalidateRemovedPlan() }
        else { _ = store.createFollowThroughPlan(loopID: currentLoopID); reload(); hasOpenedPlan = plan != nil }
    }
    private func reconcileStoredPlan(_ stored: FollowThroughPlan?) {
        guard let stored else { if hasOpenedPlan || plan != nil { invalidateRemovedPlan() }; return }
        if let draft = plan {
            guard let merged = FollowThroughAssistEngine.rebaseEditableDraft(draft, baseline: lastSavedPlan, onto: stored) else { invalidateRemovedPlan(); return }
            plan = merged
        } else { plan = stored }
        lastSavedPlan = stored
    }
    private func invalidateRemovedPlan() {
        autosave?.cancel()
        if let plan { store.followThroughRecoveryDrafts[plan.id] = nil }
        plan = nil; lastSavedPlan = nil; autosavePaused = false; wasRemoved = true; copied = false
        regenerate = false; completing = false; deleting = false; pendingObstacle = nil
    }
    private func reload() {
        autosave?.cancel(); plan = storedPlan; lastSavedPlan = storedPlan; autosavePaused = false; savingStatus = "Saved on this device"
        if let plan { store.followThroughRecoveryDrafts[plan.id] = nil }
    }
    @discardableResult private func persist(retry: Bool = false) -> Bool {
        autosave?.cancel()
        guard let plan else { return true }
        guard let stored = storedPlan, stored.id == plan.id else { invalidateRemovedPlan(); return true }
        guard let merged = FollowThroughAssistEngine.rebaseEditableDraft(plan, baseline: lastSavedPlan, onto: stored) else { invalidateRemovedPlan(); return true }
        self.plan = merged; lastSavedPlan = stored
        if merged == stored { store.followThroughRecoveryDrafts[merged.id] = nil; autosavePaused = false; savingStatus = "Saved on this device"; return true }
        store.followThroughRecoveryDrafts[merged.id] = merged
        guard !autosavePaused || retry else { return false }
        let result = store.saveFollowThroughPlan(merged)
        autosavePaused = !result
        if result { lastSavedPlan = merged }
        savingStatus = result ? "Saved on this device" : "Automatic saving paused. Retry or discard your unsaved edits."
        return result
    }
}
