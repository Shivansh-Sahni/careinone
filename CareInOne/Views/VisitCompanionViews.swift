import SwiftUI
import AVFoundation
import CareCore

struct VisitCompanionListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    @State private var creating = false
    @State private var includeFinished = false
    var body: some View {
        List {
            Section {
                Text("Walk in with your priorities. Walk out with your answers.").font(.title2.bold())
                Text("Put your three main questions first, show a short opening brief, and keep your answers in one place.").foregroundStyle(.secondary)
                Button("Prepare my appointment", systemImage: "sparkles.rectangle.stack") { creating = true }.accessibilityIdentifier("companion-create")
            }
            Section {
                Toggle("Include finished visits", isOn: $includeFinished)
                let sessions = (store.state.visitCompanions?.sessions ?? []).filter { includeFinished || $0.progress != .finished }.sorted { $0.updatedAt > $1.updatedAt }
                if sessions.isEmpty { Text("A single question is enough to start. No medical history is required.").foregroundStyle(.secondary) }
                ForEach(sessions) { session in
                    NavigationLink(value: Route.visitCompanion(session.id)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.title).font(.headline)
                            Text("\(session.questions.count) questions · \(session.answerCount) answers saved").font(.subheadline).foregroundStyle(.secondary)
                            Badge(text: session.progress.title)
                            if session.includesSynthetic { Badge(text: session.synthetic ? "Synthetic practice" : "Includes synthetic questions") }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }.navigationTitle("Appointment companion")
            .sheet(isPresented: $creating) { VisitCompanionCreateView { navigate(.visitCompanion($0)) } }
    }
}

private struct VisitCompanionCreateView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let created: (UUID) -> Void
    @State private var title = "My next appointment"
    @State private var opening = ""
    @State private var encounterID: UUID?
    @State private var synthetic = false
    @State private var initialized = false
    @State private var originalSynthetic = false
    @State private var discard = false
    private var dirty: Bool { title != "My next appointment" || !opening.isEmpty || encounterID != nil || synthetic != originalSynthetic }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("What do you most want help with?").font(.title2.bold())
                    TextField("Optional: what matters to me today", text: $opening, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("companion-opening-input")
                    Text("You can start with this one thought. Edit or add questions on the next screen.").font(.caption).foregroundStyle(.secondary)
                }
                Section("This appointment") {
                    TextField("Appointment name", text: $title).accessibilityIdentifier("companion-title-input")
                    Picker("Link an encounter", selection: $encounterID) {
                        Text("No encounter needed").tag(UUID?.none)
                        ForEach(store.state.encounters) { Text($0.title).tag(Optional($0.id)) }
                    }
                    Toggle("Synthetic practice", isOn: $synthetic).accessibilityIdentifier("companion-synthetic")
                    Text("Turn this off for your own visit. Any question copied from a synthetic source keeps its demo label.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Get ready").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Create") {
                        if let id = store.createVisitCompanion(title: title, encounterID: encounterID, opening: opening, synthetic: synthetic) { dismiss(); created(id) }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200 || opening.count > 5000).accessibilityIdentifier("companion-create-save") }
                }
                .onAppear { if !initialized { synthetic = store.state.profile.demoLoaded; originalSynthetic = synthetic; initialized = true } }
                .interactiveDismissDisabled(dirty)
                .confirmationDialog("Discard this appointment draft?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard draft", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
        }
    }
}

struct VisitCompanionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    @Environment(\.dismiss) private var dismiss
    let companionID: UUID
    @State private var editing = false
    @State private var adding = false
    @State private var showingBrief = false
    @State private var live = false
    @State private var questionToEdit: VisitCompanionQuestion?
    @State private var questionToDelete: VisitCompanionQuestion?
    @State private var deleting = false
    private var companion: VisitCompanion? { store.state.visitCompanions?.sessions.first { $0.id == companionID } }
    var body: some View {
        Group {
            if let session = companion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(session)
                        CareCard {
                            Label("What matters to me", systemImage: "heart.text.clipboard").font(.headline)
                            Text(session.opening.isEmpty ? "Add the one thing you most want help with." : session.opening).foregroundStyle(session.opening.isEmpty ? .secondary : .primary)
                            Button("Edit my opening and visit date") { editing = true }.accessibilityIdentifier("companion-edit-opening")
                        }
                        HStack {
                            Text("My first three questions").font(.title3.bold())
                            Spacer()
                            Button("Add", systemImage: "plus") { adding = true }.disabled(session.questions.count >= VisitCompanionEngine.maximumQuestions).accessibilityIdentifier("companion-add-question")
                        }
                        Text("Start with what matters most to you. Move questions up or down to choose the order.").font(.subheadline).foregroundStyle(.secondary)
                        if session.questions.isEmpty { Text("Add a question to use the visit screen. You can still show your opening brief.") }
                        ForEach(Array(session.questions.prefix(3).enumerated()), id: \.element.id) { index, question in questionCard(question, index: index, session: session) }
                        if session.questions.count > 3 {
                            DisclosureGroup("If we have time · \(session.questions.count - 3) more") {
                                VStack(spacing: 12) { ForEach(Array(session.questions.dropFirst(3).enumerated()), id: \.element.id) { index, question in questionCard(question, index: index + 3, session: session) } }.padding(.top, 12)
                            }.font(.headline)
                        }
                        if session.removedQuestionCount > 0 || session.clearedAnswerCount > 0 {
                            Text("Some copied questions or answer drafts were removed when their source evidence was deleted. Review your agenda before using it.").font(.caption).foregroundStyle(.secondary)
                        }
                        if !session.capturedSourceIDs.isEmpty {
                            CareCard {
                                Label("My saved visit evidence", systemImage: "doc.text").font(.headline)
                                ForEach(session.capturedSourceIDs, id: \.self) { SourceLink(id: $0) }
                                Text("These are your recollections. Proposed care updates still need review.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button("Remove this appointment companion", role: .destructive) { deleting = true }.font(.footnote)
                    }.padding(20)
                }.background(Theme.background)
            } else { ContentUnavailableView("Appointment companion removed", systemImage: "calendar.badge.minus") }
        }.navigationTitle("My appointment").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) { if let session = companion { VisitCompanionOpeningEditor(session: session) } }
            .sheet(isPresented: $adding) { VisitCompanionAddQuestionView(companionID: companionID) }
            .sheet(item: $questionToEdit) { VisitCompanionQuestionEditor(question: $0, companionID: companionID) }
            .sheet(isPresented: $showingBrief) { VisitCompanionBriefView(companionID: companionID) }
            .fullScreenCover(isPresented: $live) { VisitCompanionLiveView(companionID: companionID) { if let sourceID = $0 { navigate(.source(sourceID)) } } }
            .confirmationDialog("Remove this question and its answer draft?", isPresented: Binding(get: { questionToDelete != nil }, set: { if !$0 { questionToDelete = nil } }), titleVisibility: .visible) {
                Button("Remove question and draft", role: .destructive) { if let questionToDelete { _ = store.mutate { try VisitCompanionEngine.removeQuestion(questionToDelete.id, companionID: companionID, in: &$0) } }; questionToDelete = nil }
            } message: { Text("Any visit evidence already captured remains saved separately.") }
            .confirmationDialog("Remove this appointment companion?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Remove companion and drafts", role: .destructive) { if store.mutate({ VisitCompanionEngine.remove(companionID, from: &$0) }) { ExportService.clean(); dismiss() } }
            } message: { Text("This removes its opening, copied agenda, and answer drafts. Original questions and captured visit evidence stay saved.") }
    }
    private func header(_ session: VisitCompanion) -> some View {
        CareCard {
            Text(session.title).font(.title2.bold())
            HStack { Badge(text: session.progress.title); if session.includesSynthetic { Badge(text: session.synthetic ? "Synthetic practice" : "Includes synthetic questions") } }
            if let date = session.eventAt { Text(date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary) }
            Button { showingBrief = true } label: { Label("My short opening brief", systemImage: "text.bubble").frame(maxWidth: .infinity) }.buttonStyle(.bordered).accessibilityIdentifier("companion-show-brief")
            Button {
                if store.mutate({ try VisitCompanionEngine.setProgress(.inVisit, companionID: companionID, in: &$0) }) { live = true }
            } label: { Label(session.progress == .finished ? "Reopen my visit" : session.progress == .inVisit ? "Resume my visit" : "I’m at my appointment", systemImage: "person.crop.rectangle").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(session.questions.isEmpty).accessibilityIdentifier("companion-start-live")
            Text("\(session.questions.filter { $0.progress == .discussed }.count) discussed · \(session.answerCount) answers saved").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func questionCard(_ question: VisitCompanionQuestion, index: Int, session: VisitCompanion) -> some View {
        CareCard {
            HStack(alignment: .top) { Text("\(index + 1)").font(.title3.bold()).foregroundStyle(Theme.accent); Text(question.text).font(.headline); Spacer(minLength: 0) }
            Badge(text: question.progress.title)
            if question.copiedSnapshot { Text(question.editedSnapshot ? "Your edited copy for this visit" : "Copied into this visit · original stays unchanged").font(.caption).foregroundStyle(.secondary) }
            if !question.answer.isEmpty { Text(question.answer).font(.subheadline).lineLimit(3) }
            HStack {
                Button("Edit") { questionToEdit = question }.accessibilityIdentifier("companion-edit-question-\(index)")
                Spacer()
                Button { move(question.id, by: -1, session: session) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).accessibilityLabel("Move question \(index + 1) earlier")
                Button { move(question.id, by: 1, session: session) } label: { Image(systemName: "arrow.down") }.disabled(index == session.questions.count - 1).accessibilityLabel("Move question \(index + 1) later")
                Button(role: .destructive) { questionToDelete = question } label: { Image(systemName: "trash") }.accessibilityLabel("Remove question \(index + 1)")
            }.buttonStyle(.bordered)
            if !question.sourceIDs.isEmpty { DisclosureGroup("Where this question came from") { ForEach(question.sourceIDs, id: \.self) { SourceLink(id: $0) } }.font(.caption) }
        }
    }
    private func move(_ id: UUID, by offset: Int, session: VisitCompanion) {
        var ids = session.questions.map(\.id)
        guard let from = ids.firstIndex(of: id), ids.indices.contains(from + offset) else { return }
        ids.swapAt(from, from + offset)
        _ = store.mutate { try VisitCompanionEngine.reorder(ids, companionID: companionID, in: &$0) }
    }
}

private struct VisitCompanionOpeningEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let session: VisitCompanion
    @State private var title: String
    @State private var opening: String
    @State private var date: Date?
    @State private var synthetic: Bool
    @State private var discard = false
    private var dirty: Bool { title != session.title || opening != session.opening || date != session.eventAt || synthetic != session.synthetic }
    init(session: VisitCompanion) { self.session = session; _title = State(initialValue: session.title); _opening = State(initialValue: session.opening); _date = State(initialValue: session.eventAt); _synthetic = State(initialValue: session.synthetic) }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Appointment name", text: $title)
                Section("What matters most to me") { TextEditor(text: $opening).frame(minHeight: 150).accessibilityIdentifier("companion-opening-editor"); Text("Your words start the short brief. This is personal context, not an extracted medical claim.").font(.caption).foregroundStyle(.secondary) }
                OptionalDateField(title: "Visit date", date: $date)
                Toggle("Synthetic practice", isOn: $synthetic)
                Text("For your own visit, turn practice off. Answers to copied synthetic questions still stay synthetic. Add a new question in your own words for real visit answers.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("My opening").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if store.mutate({ try VisitCompanionEngine.edit(session.id, title: title, opening: opening, eventAt: date, synthetic: synthetic, in: &$0) }) { dismiss() }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200 || opening.count > 5000).accessibilityIdentifier("companion-opening-save") }
            }.interactiveDismissDisabled(dirty)
                .confirmationDialog("Discard unsaved opening changes?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
        }
    }
}

private struct VisitCompanionAddQuestionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let companionID: UUID
    @State private var text = ""
    @State private var discard = false
    private var session: VisitCompanion? { store.state.visitCompanions?.sessions.first { $0.id == companionID } }
    var body: some View {
        NavigationStack {
            List {
                Section("In my own words") {
                    TextField("What do I want to ask?", text: $text, axis: .vertical).lineLimit(2...6).accessibilityIdentifier("companion-new-question")
                    Button("Add my question") { if store.mutate({ try VisitCompanionEngine.addQuestion(text, companionID: companionID, in: &$0) }) { dismiss() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2000).accessibilityIdentifier("companion-add-own-question")
                }
                if let session {
                    let existing = Set(session.questions.map { Normalizer.key($0.text) })
                    let suggestions = VisitCompanionEngine.suggestions(store.state, encounterID: session.encounterID).filter { !existing.contains(Normalizer.key($0.text)) }
                    if !suggestions.isEmpty {
                        Section("Bring something already saved") {
                            Text("Choose what matters for this visit. Adding a suggestion copies a question, not a medical conclusion.").font(.caption).foregroundStyle(.secondary)
                            ForEach(suggestions) { suggestion in
                                Button {
                                    if store.mutate({ try VisitCompanionEngine.addSuggestion(suggestion.id, companionID: companionID, in: &$0) }) { dismiss() }
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) { Text(suggestion.text).foregroundStyle(.primary); Text(suggestion.reason).font(.caption).foregroundStyle(.secondary); if suggestion.synthetic { Badge(text: "Synthetic context") } }
                                }.accessibilityIdentifier("companion-suggestion-" + suggestion.id)
                            }
                        }
                    }
                }
            }.navigationTitle("Add a question").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { if text.isEmpty { dismiss() } else { discard = true } } } }
                .interactiveDismissDisabled(!text.isEmpty)
                .confirmationDialog("Discard your unsaved question?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard question", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
        }
    }
}

private struct VisitCompanionQuestionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let question: VisitCompanionQuestion
    let companionID: UUID
    @State private var text: String
    @State private var answer: String
    @State private var progress: VisitQuestionProgress
    @State private var discard = false
    private var dirty: Bool { text != question.text || answer != question.answer || progress != question.progress }
    init(question: VisitCompanionQuestion, companionID: UUID) { self.question = question; self.companionID = companionID; _text = State(initialValue: question.text); _answer = State(initialValue: question.answer); _progress = State(initialValue: question.progress) }
    var body: some View {
        NavigationStack {
            Form {
                Section("My question") { TextEditor(text: $text).frame(minHeight: 100).accessibilityIdentifier("companion-question-editor"); if question.copiedSnapshot { Text("This edits your visit copy. The original saved question and sources stay unchanged.").font(.caption).foregroundStyle(.secondary) } }
                Section("What I heard") { TextEditor(text: $answer).frame(minHeight: 140).accessibilityIdentifier("companion-answer-editor"); Text(question.synthetic ? "This question came from synthetic evidence. Its answers stay synthetic. Add a new question in your own words to record a real visit answer." : "Write a full answer in your own words. The question itself is never treated as an instruction.").font(.caption).foregroundStyle(.secondary) }
                Picker("My progress", selection: $progress) { ForEach(VisitQuestionProgress.allCases, id: \.self) { Text($0.title).tag($0) } }
            }.navigationTitle("My visit question").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if store.mutate({ try VisitCompanionEngine.editQuestion(question.id, text: text, answer: answer, progress: progress, companionID: companionID, in: &$0) }) { dismiss() }
                }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2000 || answer.count > 10_000).accessibilityIdentifier("companion-question-save") }
            }.interactiveDismissDisabled(dirty)
                .confirmationDialog("Discard unsaved question changes?", isPresented: $discard, titleVisibility: .visible) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                    Button("Keep editing", role: .cancel) { }
                }
        }
    }
}

private struct VisitCompanionBriefView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let companionID: UUID
    @State private var speaker = AVSpeechSynthesizer()
    @State private var pdf: PreparedTextExport?
    @State private var issue: String?
    private var session: VisitCompanion? { store.state.visitCompanions?.sessions.first { $0.id == companionID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                if let session {
                    let text = VisitCompanionEngine.openingBrief(session)
                    VStack(alignment: .leading, spacing: 20) {
                        Text(text).font(.title3).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("companion-brief-text")
                        Divider()
                        Text("Share or read this exact copy").font(.headline)
                        let speechLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
                        speechLayout {
                            Button("Read aloud", systemImage: "speaker.wave.2") {
                                speaker.stopSpeaking(at: .immediate); issue = nil
                                do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers); try AVAudioSession.sharedInstance().setActive(true); speaker.speak(AVSpeechUtterance(string: text)) } catch { issue = "Read aloud is unavailable. Your brief is still available on screen." }
                            }.accessibilityIdentifier("companion-read-aloud")
                            Button("Stop", systemImage: "stop.fill") { stop() }
                        }.buttonStyle(.bordered)
                        ShareLink("Share my opening brief", item: text).accessibilityIdentifier("companion-share-brief")
                        Button("Create brief PDF", systemImage: "doc.richtext") {
                            pdf?.discard(); pdf = nil; issue = nil
                            do { pdf = try ExportService.preparedPDF(text, name: "CareInOne-appointment.pdf") }
                            catch { issue = error.localizedDescription }
                        }.accessibilityIdentifier("companion-brief-pdf")
                        if let pdf, pdf.isAvailable(for: text) { ShareLink("Share brief PDF", item: pdf.url) }
                        if let issue { Text(issue).foregroundStyle(Theme.warning) }
                    }.padding(24)
                } else { ContentUnavailableView("Companion removed", systemImage: "calendar.badge.minus") }
            }.navigationTitle("My short opening").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { stop(); dismiss() } } }
                .onDisappear { stop() }
                .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
                .onChange(of: session) { _, _ in pdf?.discard(); pdf = nil; issue = nil; stop() }
        }
    }
    private func stop() { speaker.stopSpeaking(at: .immediate); try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}

private struct VisitCompanionLiveView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let companionID: UUID
    let finished: (UUID?) -> Void
    @State private var answer = ""
    @State private var loadedQuestionID: UUID?
    @State private var autosave: Task<Void, Never>?
    @State private var saveFailed = false
    @State private var ending = false
    @State private var showingBrief = false
    @State private var loaded = false
    private var session: VisitCompanion? { store.state.visitCompanions?.sessions.first { $0.id == companionID } }
    private var question: VisitCompanionQuestion? { session?.questions.first { $0.id == session?.currentQuestionID } ?? session?.questions.first }
    private var dirty: Bool { loadedQuestionID == question?.id && answer != question?.answer }
    var body: some View {
        CareNavigationStack {
            Group {
                if let session, let question {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if ending { finishCard(session) }
                            else {
                                let progressLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
                                progressLayout {
                                    Text("Question \((session.questions.firstIndex { $0.id == question.id } ?? 0) + 1) of \(session.questions.count)").font(.caption.weight(.semibold))
                                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                    Badge(text: question.progress.title)
                                }
                                Text(question.text).font(.largeTitle.bold()).accessibilityIdentifier("companion-live-question")
                                if session.includesSynthetic { Badge(text: session.synthetic ? "Synthetic practice" : "Includes synthetic questions") }
                                Button("Show my opening brief", systemImage: "text.bubble") { if saveAnswer() { showingBrief = true } }
                                CareCard {
                                    Text("What I heard").font(.headline)
                                    TextEditor(text: $answer).frame(minHeight: 150).accessibilityLabel("What I heard").accessibilityIdentifier("companion-live-answer")
                                    Text(question.synthetic ? "This is a copied synthetic question. Its answer stays synthetic. For real visit notes, add your own question from your agenda." : "Use a full thought, such as the test name and what was said. Your notes are not clinician-verified.").font(.caption).foregroundStyle(.secondary)
                                    Text("\(answer.count.formatted()) / 10,000 characters").font(.caption).foregroundStyle(answer.count > 10_000 ? Theme.warning : .secondary).accessibilityIdentifier("companion-answer-count")
                                    Text(answer.count > 10_000 ? "Shorten this answer to 10,000 characters before saving or opening another screen. Your text is still here." : saveFailed ? "Not saved yet. Your text is still here; tap Save answer to retry." : dirty ? "Saving your draft…" : "Draft saved on this device").font(.caption).foregroundStyle(saveFailed || answer.count > 10_000 ? Theme.warning : .secondary).accessibilityIdentifier("companion-save-status")
                                    Button("Save answer") { _ = saveAnswer() }.disabled(answer.count > 10_000).accessibilityIdentifier("companion-save-answer")
                                }
                                Button("We discussed this", systemImage: "checkmark.bubble") { mark(.discussed) }.buttonStyle(.borderedProminent).accessibilityIdentifier("companion-discussed")
                                Button("Ask this later", systemImage: "clock") { mark(.later) }.buttonStyle(.bordered).accessibilityIdentifier("companion-ask-later")
                                HStack {
                                    Button("Previous", systemImage: "chevron.left") { move(-1) }.disabled(session.questions.first?.id == question.id)
                                    Spacer()
                                    Button("Next", systemImage: "chevron.right") { move(1) }.disabled(session.questions.last?.id == question.id).accessibilityIdentifier("companion-next")
                                }.buttonStyle(.bordered)
                                Text("Marking a question discussed keeps track of your conversation. It does not confirm a medical decision.").font(.caption).foregroundStyle(.secondary)
                                if !question.sourceIDs.isEmpty { DisclosureGroup("Saved context for this question") { ForEach(question.sourceIDs, id: \.self) { VisitCompanionGuardedSourceLink(sourceID: $0, saveBeforeOpening: saveAnswer) } }.font(.subheadline) }
                            }
                        }.padding(24)
                    }.background(Theme.background)
                } else { ContentUnavailableView("No questions remain", systemImage: "questionmark.bubble", description: Text("Close this screen to add another question.")) }
            }.navigationTitle(ending ? "Before I leave" : "In my appointment").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Pause") { if saveAnswer() { dismiss() } }.accessibilityIdentifier("companion-pause") }
                    ToolbarItem(placement: .confirmationAction) { Button(ending ? "Questions" : "Finish") { if saveAnswer() { ending.toggle() } }.accessibilityIdentifier("companion-finish") }
                }
                .interactiveDismissDisabled(dirty)
                .sheet(isPresented: $showingBrief) { VisitCompanionBriefView(companionID: companionID) }
                .onAppear { loadQuestion() }
                .onChange(of: question?.id) { _, _ in loadQuestion(force: true) }
                .onChange(of: session?.clearedAnswerCount) { _, _ in loadQuestion(force: true) }
                .onChange(of: question?.answer) { oldValue, value in if loadedQuestionID == question?.id, answer == (oldValue ?? "") { answer = value ?? "" } }
                .onChange(of: answer) { _, _ in queueSave() }
                .onChange(of: scenePhase) { _, phase in if phase != .active && !saveFailed { _ = saveAnswer() } }
                .onDisappear { autosave?.cancel(); if !saveFailed { _ = saveAnswer() } }
        }
    }
    private func finishCard(_ session: VisitCompanion) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Leave with fewer loose ends.").font(.largeTitle.bold())
            CareCard {
                Text("If anything is still unclear, ask:").font(.headline)
                Label("What happens next, and who arranges it?", systemImage: "arrow.right.circle")
                Label("When should I expect it?", systemImage: "calendar")
                Label("Where can I find the written instructions?", systemImage: "doc.text")
                Label("Who can I contact with questions?", systemImage: "person.crop.circle.badge.questionmark")
            }
            Text("\(session.answerCount) answers saved · \(session.questions.filter { $0.progress != .discussed }.count) questions not marked discussed").font(.headline)
            Text("Partial notes are welcome. Saving creates patient-reported evidence from your answer text only. Nothing updates My Care until you review it.").foregroundStyle(.secondary)
            if !session.synthetic && session.questions.contains(where: { $0.synthetic && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) && session.questions.contains(where: { !$0.synthetic && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                Text("Your answers mix real visit notes and synthetic practice. Clear the answer to the synthetic question before saving real visit evidence, or keep these drafts and use a separate companion.").foregroundStyle(Theme.warning)
            }
            Button("Save answers as evidence and review", systemImage: "doc.badge.plus") {
                guard saveAnswer() else { return }
                if let id = store.captureVisitCompanionAnswers(companionID) { dismiss(); finished(id) }
            }.buttonStyle(.borderedProminent).disabled(session.answerCount == 0).accessibilityIdentifier("companion-capture-answers")
            Button("Finish and keep my drafts") {
                if saveAnswer(), store.mutate({ try VisitCompanionEngine.setProgress(.finished, companionID: companionID, in: &$0) }) { dismiss(); finished(nil) }
            }.buttonStyle(.bordered).accessibilityIdentifier("companion-finish-drafts")
            Text("Finishing only closes this visit screen. It does not close tasks or mark care complete. You can reopen it anytime.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func loadQuestion(force: Bool = false) {
        // Returning from a pushed source must never replace a draft that could not be saved.
        // Explicit source deletion and actual question changes force a fresh load.
        if !force, loadedQuestionID == question?.id, dirty { loaded = true; return }
        autosave?.cancel(); loaded = false; loadedQuestionID = question?.id; answer = question?.answer ?? ""; saveFailed = false; loaded = true
    }
    private func queueSave() {
        autosave?.cancel()
        guard loaded, dirty, !saveFailed, answer.count <= 10_000 else { return }
        autosave = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(900)); try Task.checkCancellation(); _ = saveAnswer() } catch { }
        }
    }
    @discardableResult private func saveAnswer() -> Bool {
        autosave?.cancel()
        guard let questionID = loadedQuestionID else { return true }
        guard session?.questions.contains(where: { $0.id == questionID }) == true else { answer = ""; return true }
        guard dirty else { saveFailed = false; return true }
        guard answer.count <= 10_000 else { saveFailed = true; return false }
        let saved = store.mutate { try VisitCompanionEngine.saveAnswer(answer, questionID: questionID, companionID: companionID, in: &$0) }
        saveFailed = !saved; return saved
    }
    private func move(_ offset: Int) {
        guard saveAnswer(), let session, let question, let index = session.questions.firstIndex(where: { $0.id == question.id }), session.questions.indices.contains(index + offset) else { return }
        _ = store.mutate { try VisitCompanionEngine.setPosition(session.questions[index + offset].id, companionID: companionID, in: &$0) }
    }
    private func mark(_ progress: VisitQuestionProgress) {
        guard saveAnswer(), let question else { return }
        if store.mutate({ try VisitCompanionEngine.markQuestion(progress, questionID: question.id, companionID: companionID, in: &$0) }) {
            if session?.questions.last?.id == question.id { ending = true } else { move(1) }
        }
    }
}

/// This child reads the live companion's own navigation environment, rather than the
/// parent tab's stack. It saves the answer before allowing supporting-source navigation.
private struct VisitCompanionGuardedSourceLink: View {
    @Environment(AppStore.self) private var store
    @Environment(\.careNavigate) private var navigate
    let sourceID: UUID
    let saveBeforeOpening: @MainActor () -> Bool
    var body: some View {
        if let source = store.source(sourceID) {
            Button {
                guard saveBeforeOpening() else { return }
                navigate(.source(sourceID))
            } label: {
                Label(source.title, systemImage: "doc.text.magnifyingglass").font(.subheadline).multilineTextAlignment(.leading)
            }.buttonStyle(.plain).foregroundStyle(Theme.accent).accessibilityIdentifier("companion-context-source")
        }
    }
}
