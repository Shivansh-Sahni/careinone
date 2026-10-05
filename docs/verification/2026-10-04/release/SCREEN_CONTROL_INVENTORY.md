# Source screen and control inventory

Generated from the inspected Swift source. This is a reachability and audit checklist, **not** proof that every conditional control has been exercised. Source hashes and individual line/control contexts are saved in [control-inventory.json](control-inventory.json). Dynamic care records produce repeated instances, and iOS supplies picker, share, permission and keyboard controls that need separate hands-on checks. See [FEATURE_VERIFICATION.md](FEATURE_VERIFICATION.md) for actual test evidence and limitations.

Inventory: 82 view/component structures, 580 explicit control construction sites, 82 presentation/search/open-file sites. Reusable visual components are included so their source-owned controls do not disappear from the audit.

## CareInOne/Views/BackupView.swift

### BackupView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 24 | SecureField | At least 12 characters |
| 30 | SecureField | Repeat passphrase |
| 33 | Toggle | Include retained audio |
| 35 | Button | Create encrypted backup |
| 39 | ShareLink | Save or share encrypted backup |
| 43 | Button | Choose backup file |
| 46 | Button | Unlock and preview |
| 55 | Button | Replace local records with this backup |
| 61 | Button | Cancel operation |
| 67 | Button | Done |
| 83 | Button | Restore and replace records |

Presentation/search entry points: `fileImporter` at 74, `confirmationDialog` at 82.

## CareInOne/Views/CaptureView.swift

### CaptureView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 51 | Button | Done |
| 55 | Button | Cancel |
| 60 | Button | Discard capture |
| 66 | Button | Keep editing |
| 69 | Button | Replace working text |
| 73 | Button | Keep current text |
| 108 | Button | Dynamic / supplied by parent |
| 119 | Button | Take a photo |
| 122 | PhotosPicker | Choose photo or screenshot |
| 127 | Button | Dynamic / supplied by parent |
| 131 | Button | Cancel processing |
| 135 | TextField | Title, e.g. Cardiology recap |
| 140 | EvidenceTextEditor | Dynamic / supplied by parent |
| 145 | DisclosureGroup | Event date, provider, and encounter |
| 146 | OptionalDateField | Unassigned |
| 147 | TextField | Provider or practice |
| 148 | Picker | Same encounter |
| 152 | Button | Create encounter from this source |
| 160 | Button | Save evidence & review |
| 168 | Picker | Category |
| 169 | TextField | Item name |
| 170 | Picker | Reported action |
| 171 | TextField | Value or instructions |
| 172 | TextField | Numeric value (optional) |
| 173 | TextField | Unit (optional) |
| 175 | TextField | Route, e.g. oral |
| 176 | TextField | Frequency, e.g. once daily |
| 177 | TextField | Form, e.g. extended-release tablet |
| 179 | OptionalDateField | Dynamic / supplied by parent |
| 180 | Toggle | Appointment time is known |
| 181 | OptionalDateField | Dynamic / supplied by parent |

Presentation/search entry points: `confirmationDialog` at 59, `confirmationDialog` at 68, `fileImporter` at 75, `sheet` at 83.

### EvidenceTextEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 320 | TextEditor | Dynamic / supplied by parent |
| 328 | Button | Done editing text |

### RecordingCaptureView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 349 | Toggle | Everyone present has agreed to this recording |
| 350 | Button | Dynamic / supplied by parent |
| 355 | Button | Dynamic / supplied by parent |
| 355 | Button | Stop & transcribe |
| 358 | Button | Cancel transcription |
| 359 | Button | Retry local transcription |

### CameraPicker

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

## CareInOne/Views/CareViews.swift

### MyCareView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 10 | NavigationLink | Care connections |
| 14 | NavigationLink | \(store.state.entities.filter { $0.kind == kind }.count) |
| 18 | NavigationLink | Follow-through |
| 19 | NavigationLink | Questions |
| 20 | NavigationLink | Personal notes |
| 21 | NavigationLink | Trends |
| 22 | NavigationLink | Care Network |
| 23 | NavigationLink | Care Brief |
| 24 | NavigationLink | Search saved care and sources |

### CategoryView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 38 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `searchable` at 42.

### EntityDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 69 | Button | Remove alias |
| 75 | DisclosureGroup | Add an alias you recognize |
| 76 | TextField | Alias |
| 77 | Button | Save alias |
| 83 | NavigationLink | Saved records disagree · open clarification inbox |
| 84 | NavigationLink | Related follow-through |
| 85 | NavigationLink | Questions about this item |
| 86 | NavigationLink | Trace the evidence behind this item |
| 87 | NavigationLink | Medical dates and when added here |
| 99 | SourceLink | Fictional practice keeps your personal calendar unchanged. |
| 103 | Button | Dynamic / supplied by parent |
| 108 | Button | Add another calendar copy… |
| 115 | NavigationLink | Your notes |
| 119 | Button | Edit note |
| 121 | TextField | A thought to carry forward |
| 122 | Button | Save note |
| 130 | Button | Remove alias |
| 137 | Button | Keep alias |
| 140 | Button | Add another copy |
| 141 | Button | Cancel |

Presentation/search entry points: `sheet` at 127, `confirmationDialog` at 128, `confirmationDialog` at 139.

### ChangesView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 169 | Picker | Category |
| 170 | Picker | Provider |
| 171 | OptionalDateField | Dynamic / supplied by parent |
| 172 | Toggle | Group by encounter |
| 184 | SourceLink | Dynamic / supplied by parent |

## CareInOne/Views/CloudConnectionView.swift

### CloudConnectionView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 26 | TextField | Gateway HTTPS URL |
| 27 | SecureField | Gateway access token |
| 29 | Button | Check gateway configuration |
| 37 | Button | Test with synthetic text |
| 41 | Button | Cancel |
| 45 | Button | Save connection |
| 50 | Button | Allow cloud analysis with these models |

## CareInOne/Views/ContinuityViews.swift

### ContinuityHubView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 17 | Button | Start a visit workspace |
| 18 | NavigationLink | Care checkpoints |
| 21 | Toggle | Include archived workspaces |
| 24 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 34.

### WorkspaceEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 58 | TextField | Name this visit |
| 59 | Picker | Encounter |
| 64 | TextField | My priorities |
| 70 | Button | Cancel |
| 71 | Button | Save workspace |
| 75 | Button | Discard changes |
| 76 | Button | Keep editing |

Presentation/search entry points: `alert` at 74.

### CheckpointsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 103 | Button | Save a care checkpoint |
| 106 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 115.

### CheckpointEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 131 | TextField | Checkpoint name |
| 137 | Button | Cancel |
| 139 | Button | Save checkpoint |

### CheckpointDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 167 | Button | Preview comparison for export |
| 171 | DisclosureGroup | Browse \(checkpoint.facts.count) saved reports |
| 176 | SourceLink | Dynamic / supplied by parent |
| 182 | Button | Rename checkpoint |
| 183 | Button | Delete checkpoint |
| 191 | Button | Delete checkpoint |

Presentation/search entry points: `sheet` at 188, `sheet` at 189, `confirmationDialog` at 190.

### ComparisonSections

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 209 | Picker | Show |
| 218 | DisclosureGroup | Before |
| 219 | DisclosureGroup | After |
| 221 | SourceLink | Dynamic / supplied by parent |
| 222 | NavigationLink | Open care item |

### ComparisonExportView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 237 | ShareLink | Share comparison text |
| 238 | Button | Create comparison PDF |
| 243 | ShareLink | Share comparison PDF |
| 247 | Button | Done |

## CareInOne/Views/DemoWorkspaceView.swift

### DemoWorkspaceView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 19 | Button | Dynamic / supplied by parent |

## CareInOne/Views/DesignSystem.swift

### CareCard

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### Badge

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### SectionHeading

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### SourceLink

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 25 | NavigationLink | Dynamic / supplied by parent |

### ClaimSummary

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### CareNavigationStack

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### CareDestinations

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### EmptyCard

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### OptionalDateField

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 108 | Toggle | Dynamic / supplied by parent |
| 109 | DatePicker | Dynamic / supplied by parent |

## CareInOne/Views/EvidenceImpactView.swift

### EvidenceImpactView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 30 | Button | Delete source and linked evidence |
| 35 | Button | Done |
| 37 | Button | Delete source |

Presentation/search entry points: `confirmationDialog` at 36.

## CareInOne/Views/EvidenceIntelligenceViews.swift

### EvidenceIntelligenceView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 12 | NavigationLink | Evidence map |
| 15 | NavigationLink | Two-date timeline |
| 18 | NavigationLink | Tracked handoffs |
| 23 | NavigationLink | Leave sources out · temporary preview |

### EvidenceMapView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 43 | Picker | Start from |
| 47 | NavigationLink | Dynamic / supplied by parent |
| 51 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `searchable` at 55.

### EvidenceTraceView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 80 | NavigationLink | Open this care item |
| 81 | SourceLink | Dynamic / supplied by parent |
| 90 | NavigationLink | Dynamic / supplied by parent |
| 91 | DisclosureGroup | Evidence and status |
| 92 | SourceLink | Dynamic / supplied by parent |
| 102 | Picker | Trace |

### EvidenceTimelineView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 121 | Picker | Order by |
| 122 | Toggle | Reviewed reports only |
| 148 | SourceLink | Dynamic / supplied by parent |
| 149 | NavigationLink | Trace this evidence |

Presentation/search entry points: `searchable` at 132.

### SourceOmissionView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 167 | Button | Dynamic / supplied by parent |
| 168 | Button | Cancel preview |
| 170 | Button | Clear temporary preview |
| 184 | Toggle | Dynamic / supplied by parent |

## CareInOne/Views/FollowThroughAssistView.swift

### FollowThroughAssistView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 47 | Picker | Helper section |
| 62 | Button | I've completed this care task |
| 65 | Button | Remove this helper plan |
| 74 | Button | Start a new helper plan |
| 80 | Button | Try again |
| 86 | Button | Back |
| 87 | Button | Done editing text |
| 105 | Button | Create a fresh message |
| 110 | Button | Keep my draft |
| 113 | Button | Yes, I completed it |
| 119 | Button | Remove plan |
| 125 | Button | Discard unsaved edits |
| 133 | Button | Retry save |
| 134 | Button | Discard unsaved edits |
| 142 | SourceLink | Dynamic / supplied by parent |
| 146 | Picker | Connect to current care task |
| 150 | Button | Reconnect this helper |
| 166 | Button | Dynamic / supplied by parent |
| 184 | TextField | Office or person (optional) |
| 186 | Button | Update message for my situation |
| 190 | EvidenceTextEditor | Dynamic / supplied by parent |
| 194 | Button | Dynamic / supplied by parent |
| 198 | ShareLink | Share |
| 206 | Picker | I'll |
| 207 | Toggle | Choose a personal check-back time |
| 209 | DatePicker | My check-back time |
| 220 | Button | Enable private reminders in Settings |
| 227 | TextField | A note for next time (optional) |
| 231 | Button | Dynamic / supplied by parent |
| 252 | EvidenceTextEditor | Dynamic / supplied by parent |
| 255 | OptionalDateField | Dynamic / supplied by parent |
| 256 | Toggle | This reply is synthetic demo information |
| 257 | Button | Save reply & review |
| 262 | SourceLink | Why this is in my care |
| 269 | SourceLink | See the full care history |
| 270 | NavigationLink | See the full care history |

Presentation/search entry points: `confirmationDialog` at 104, `confirmationDialog` at 112, `confirmationDialog` at 118, `confirmationDialog` at 124.

## CareInOne/Views/FollowThroughViews.swift

### ConflictsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 10 | Toggle | Include clarified & dismissed |
| 14 | Button | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 16.

### ConflictDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 39 | Button | Save this question |
| 42 | TextField | Your resolution note |
| 44 | Button | Mark clarified |
| 45 | Button | Dismiss from inbox |
| 46 | Button | Reopen discrepancy |
| 50 | Button | Done |
| 51 | Button | Done editing resolution note |
| 55 | Button | Discard changes |
| 56 | Button | Keep editing |
| 67 | SourceLink | Dynamic / supplied by parent |

Presentation/search entry points: `alert` at 54.

### LoopsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 77 | Toggle | Include completed & dismissed |
| 82 | Button | Dynamic / supplied by parent |
| 85 | NavigationLink | Help me get this done |
| 94 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 100.

### LoopDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 129 | TextField | Notes |
| 130 | OptionalDateField | Dynamic / supplied by parent |
| 131 | Picker | Precision |
| 132 | Button | Save notes & date |
| 133 | Button | I completed this |
| 134 | Button | I’m unsure whether this is complete |
| 135 | Button | Reopen this step |
| 136 | Button | Dismiss this step |
| 139 | SourceLink | Dynamic / supplied by parent |
| 140 | NavigationLink | Related encounter |
| 143 | Button | Done |
| 144 | Button | Done editing follow-through note |
| 148 | Button | Discard changes |
| 149 | Button | Keep editing |

Presentation/search entry points: `alert` at 147.

## CareInOne/Views/HandoffViews.swift

### HandoffsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 13 | NavigationLink | Choose a new handoff packet |
| 14 | Toggle | Include finished handoffs |
| 17 | NavigationLink | For:  |

### HandoffCreateView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 45 | TextField | Name this handoff |
| 46 | TextField | Who is it for? (optional) |
| 57 | Button | Cancel |
| 58 | Button | Save handoff |

### HandoffDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 88 | Button | Review exact outgoing copy |
| 90 | Button | I shared this copy |
| 99 | NavigationLink | Choose an updated packet |
| 105 | Button | Reopen handoff |
| 109 | Button | Dynamic / supplied by parent |
| 111 | SourceLink | Dynamic / supplied by parent |
| 114 | Button | Mark handoff finished |
| 116 | Button | Delete handoff |
| 124 | Button | Finish handoff |
| 127 | Button | Delete handoff |
| 144 | SourceLink | First 100 changes shown. Build an updated packet to review the current selection. |

Presentation/search entry points: `sheet` at 121, `sheet` at 122, `confirmationDialog` at 123, `confirmationDialog` at 126.

### HandoffSnapshotView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 167 | ShareLink | Share exact text |
| 168 | Button | Create handoff PDF |
| 173 | ShareLink | Share handoff PDF |
| 175 | DisclosureGroup | Copy identifier |
| 183 | Button | Done |

### HandoffReplyView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 210 | TextEditor | Dynamic / supplied by parent |
| 211 | OptionalDateField | Dynamic / supplied by parent |
| 212 | Toggle | This reply is synthetic demo material |
| 215 | Button | Save reply as evidence |
| 224 | Button | Cancel |
| 225 | Button | Save draft |
| 230 | Button | Discard changes |

Presentation/search entry points: `confirmationDialog` at 230.

## CareInOne/Views/HelpPrivacyView.swift

### HelpPrivacyView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 24 | NavigationLink | Encrypted backup & restore |
| 30 | NavigationLink | Review cloud connection |
| 46 | Link | Read the privacy policy |
| 48 | Link | CareInOne support |

## CareInOne/Views/OnboardingView.swift

### OnboardingView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 16 | TextField | Your first name (optional) |
| 27 | Button | Explore the fictional demo |
| 28 | Button | Start with an empty care memory |
| 34 | Button | Dynamic / supplied by parent |

## CareInOne/Views/PatientEditors.swift

### QuestionEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 16 | TextField | What would you like to ask? |
| 18 | EvidenceTextEditor | Dynamic / supplied by parent |
| 19 | Toggle | Answered |
| 23 | Picker | Encounter |
| 29 | Button | Cancel |
| 30 | Button | Done editing text |
| 32 | Button | Save |
| 43 | Button | Discard changes |
| 44 | Button | Keep editing |

Presentation/search entry points: `alert` at 42.

### EncounterEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 65 | TextField | Encounter title |
| 66 | TextField | Provider or practice |
| 67 | OptionalDateField | An encounter groups sources and questions from the same visit. Editing its label does not rewrite clinical claims or their event dates. |
| 69 | Button | Remove encounter grouping |
| 71 | Button | Cancel |
| 72 | Button | Done editing text |
| 74 | Button | Save |
| 84 | Button | Remove grouping |
| 99 | Button | Discard changes |
| 100 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 83, `alert` at 98.

### NoteEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 119 | EvidenceTextEditor | Dynamic / supplied by parent |
| 121 | Picker | Related item |
| 127 | Button | Save changes |
| 136 | Button | Delete note |
| 138 | Button | Cancel |
| 141 | Button | Discard changes |
| 142 | Button | Keep editing |
| 145 | Button | Delete note permanently |

Presentation/search entry points: `alert` at 140, `confirmationDialog` at 144.

## CareInOne/Views/PatientWorkflowViews.swift

### VisitsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 11 | NavigationLink | Appointment companion |
| 19 | NavigationLink | Visit workspaces |
| 20 | NavigationLink | Care checkpoints |
| 21 | NavigationLink | Tracked handoffs |
| 26 | NavigationLink | Dynamic / supplied by parent |
| 27 | NavigationLink | Prepare for your next visit |
| 30 | Button | Add an encounter |
| 32 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 35.

### PrepareView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 51 | Button | Start my appointment companion |
| 54 | NavigationLink | Choose a visit packet |
| 56 | Button | Open a connected visit workspace |
| 57 | NavigationLink | Open visit workspaces |
| 58 | NavigationLink | Create a complete Care Brief |
| 59 | Button | Edit encounter details |
| 62 | Button | Save question |
| 63 | NavigationLink | Open discrepancies |
| 67 | NavigationLink | Help me get this done |
| 71 | NavigationLink | Manage follow-through |
| 75 | NavigationLink | Write or answer a question |
| 78 | SourceLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 81.

### SearchView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 95 | SourceLink | Dynamic / supplied by parent |
| 96 | NavigationLink | View care item |
| 97 | NavigationLink | View personal notes |
| 98 | NavigationLink | View questions |

Presentation/search entry points: `searchable` at 101.

### AskView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 121 | TextField | e.g. What is saved about metoprolol? |
| 122 | Button | Find in my saved care |
| 126 | NavigationLink | Search original sources |
| 134 | SourceLink | Dynamic / supplied by parent |
| 137 | Button | Save this as a question for my care team |

### QuestionsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 177 | TextField | What do you want to ask? |
| 177 | Button | Save question |
| 178 | Toggle | Include answered questions |
| 184 | Button | Dynamic / supplied by parent |
| 185 | SourceLink | Dynamic / supplied by parent |
| 186 | Button | Delete question |
| 191 | Button | Done editing question |
| 195 | Button | Delete question permanently |
| 203 | Button | Keep question |

Presentation/search entry points: `sheet` at 189, `alert` at 193.

### CareNetworkView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 215 | SourceLink | Dynamic / supplied by parent |
| 217 | NavigationLink | Dynamic / supplied by parent |

### TrendsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 250 | SourceLink | Dynamic / supplied by parent |

### PersonalNotesView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 269 | Button | Write a personal note |
| 276 | NavigationLink | Dynamic / supplied by parent |
| 277 | Button | Edit note |

Presentation/search entry points: `searchable` at 281, `sheet` at 282, `sheet` at 283.

## CareInOne/Views/ReviewEditor.swift

### ReviewEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 26 | DisclosureGroup | Choose an exact supporting passage |
| 27 | EvidenceTextEditor | Dynamic / supplied by parent |
| 36 | Picker | Category |
| 37 | TextField | Label |
| 38 | Picker | Action |
| 39 | TextField | Value / instruction |
| 40 | TextField | Numeric value |
| 41 | TextField | Unit |
| 42 | TextField | Route |
| 42 | TextField | Frequency |
| 42 | TextField | Form |
| 45 | DisclosureGroup | Edit event, effective, or due date |
| 46 | OptionalDateField | Dynamic / supplied by parent |
| 47 | OptionalDateField | Dynamic / supplied by parent |
| 48 | Toggle | Appointment time is known |
| 49 | OptionalDateField | Dynamic / supplied by parent |
| 50 | Picker | Due-date precision |
| 51 | TextField | Follow-up interval in days |
| 56 | Picker | About |
| 57 | Picker | State |
| 58 | DisclosureGroup | Conditionality, negation & speaker |
| 59 | Toggle | Conditional / only if |
| 60 | Toggle | Negated / says this is not present |
| 61 | TextField | Speaker (if known) |
| 62 | Toggle | Speaker is uncertain |
| 63 | Button | Mark historical |
| 64 | Button | Mark uncertain |
| 65 | Button | Not about me |
| 69 | DisclosureGroup | Review association or explicit replacement |
| 70 | Picker | Entity association |
| 75 | Button | Associate with this item |
| 77 | Picker | Explicitly replaces earlier claim |
| 82 | Picker | Related care item |
| 87 | Picker | Relationship from this item |
| 96 | Toggle | This accurately reflects what was reported |
| 100 | Button | Preview changes to my care |
| 104 | Button | Dynamic / supplied by parent |
| 105 | Button | Dynamic / supplied by parent |
| 110 | Button | Cancel |
| 113 | Button | Discard changes |
| 114 | Button | Keep editing |
| 125 | Button | Withdraw report |

Presentation/search entry points: `alert` at 112, `sheet` at 123, `confirmationDialog` at 124.

## CareInOne/Views/SampleEvidenceView.swift

### SampleEvidenceView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 16 | Button | Import and review |
| 25 | ShareLink | Save sample to Files |
| 31 | Button | Reload practice files |

## CareInOne/Views/SettingsView.swift

### SettingsView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 17 | TextField | Display name |
| 18 | OptionalDateField | Dynamic / supplied by parent |
| 19 | TextField | Emergency / primary contact |
| 20 | TextField | Contact phone |
| 23 | Toggle | Allow cloud analysis |
| 26 | NavigationLink | Set up or test cloud connection |
| 30 | Picker | Text recognition language |
| 35 | Toggle | App lock |
| 36 | Toggle | Keep audio after successful transcription |
| 41 | Toggle | Enable local reminders |
| 42 | Toggle | Explicit dated follow-through |
| 42 | Toggle | Upcoming appointments |
| 49 | Button | Retry reminder setup |
| 54 | Button | Save preferences |
| 58 | NavigationLink | Practice text, PDF, photo & FHIR imports |
| 60 | Button | Reset fictional demo |
| 63 | Button | Explore the fictional demo |
| 64 | Button | Remove older synthetic examples from my care |
| 69 | NavigationLink | Encrypted backup & restore |
| 70 | Button | Export care graph as JSON |
| 74 | ShareLink | Share exported graph |
| 76 | Button | Rebuild derived care graph |
| 77 | Button | Delete all local data |
| 80 | NavigationLink | How it works & privacy |
| 83 | DisclosureGroup | Local audit activity · no health content |
| 89 | Button | Permanently delete all local data |
| 90 | Button | Remove synthetic data |
| 91 | Button | Reset demo |

Presentation/search entry points: `confirmationDialog` at 89, `confirmationDialog` at 90, `confirmationDialog` at 91.

### CareBriefView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 129 | NavigationLink | Choose what to include |
| 130 | ShareLink | Share complete text brief |
| 131 | Button | Create PDF for sharing |
| 136 | ShareLink | Share Care Brief PDF |

## CareInOne/Views/SourceViews.swift

### SourcesView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 18 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `searchable` at 20.

### SourceRow

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

### SourceDetailView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 62 | NavigationLink | Dynamic / supplied by parent |
| 63 | Button | Edit title, date, or working text |
| 64 | NavigationLink | What this source informs |
| 65 | Button | Open original file |
| 67 | ShareLink | Export original file |
| 70 | Button | Prepare original text export |
| 74 | ShareLink | Save or share original text |
| 77 | Button | Dynamic / supplied by parent |
| 78 | ShareLink | Export saved audio |
| 79 | Button | Delete audio only |
| 81 | Button | Retry on-device transcription |
| 91 | Button | Cancel transcription |
| 96 | Button | Cancel analysis |
| 101 | Button | Retry text extraction from original |
| 103 | Button | Dynamic / supplied by parent |
| 103 | Button | Use local analysis |
| 105 | Button | Add a structured claim from this source |
| 113 | Button | Accept \(safe.count) low-risk, high-confidence items |
| 120 | Button | Review & edit |
| 120 | Button | Reject |
| 131 | NavigationLink | View item & history |
| 132 | Button | Correct this saved report |
| 138 | DisclosureGroup | Working text |
| 139 | DisclosureGroup | Original captured text |
| 140 | DisclosureGroup | Earlier working versions (\(source.previousText.count)) |
| 143 | DisclosureGroup | Earlier or withdrawn reports (\(rejected.count)) |
| 147 | Button | Review this report again |
| 153 | Button | Delete source and its claims |
| 162 | Button | Delete audio |

Presentation/search entry points: `sheet` at 158, `sheet` at 159, `sheet` at 160, `sheet` at 161, `confirmationDialog` at 162.

### SourceEditView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 184 | TextField | Title |
| 184 | OptionalDateField | Unassigned |
| 184 | TextField | Provider |
| 185 | Picker | Encounter |
| 188 | EvidenceTextEditor | Dynamic / supplied by parent |
| 193 | Button | Cancel |
| 195 | Button | Save |
| 205 | Button | Discard edits |
| 206 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 204.

### QuickLookView

Display/container/platform bridge; no directly constructed SwiftUI control in this range. Child controls or iOS-managed controls may still appear.

## CareInOne/Views/TodayView.swift

### TodayView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 29 | Button | Add an update |
| 34 | NavigationLink | Dynamic / supplied by parent |
| 42 | NavigationLink | Care connections |
| 43 | NavigationLink | Visit workspaces |
| 44 | NavigationLink | Prepare |
| 44 | NavigationLink | Care Brief |
| 45 | NavigationLink | Ask saved info |
| 45 | NavigationLink | Search |
| 50 | NavigationLink | \(count) |
| 55 | NavigationLink | See all |
| 58 | NavigationLink | Dynamic / supplied by parent |
| 60 | NavigationLink | Help me get this done |
| 62 | DisclosureGroup | Why this is shown |
| 63 | SourceLink | YOUR APPOINTMENT COMPANION |
| 79 | Button | Dynamic / supplied by parent |
| 84 | NavigationLink | All my appointment companions |
| 95 | NavigationLink | Dynamic / supplied by parent |

## CareInOne/Views/VisitCompanionViews.swift

### VisitCompanionListView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 15 | Button | Prepare my appointment |
| 18 | Toggle | Include finished visits |
| 22 | NavigationLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 33.

### VisitCompanionCreateView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 54 | TextField | Optional: what matters to me today |
| 58 | TextField | Appointment name |
| 59 | Picker | Link an encounter |
| 63 | Toggle | Synthetic practice |
| 68 | Button | Cancel |
| 69 | Button | Create |
| 76 | Button | Discard draft |
| 77 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 75.

### VisitCompanionView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 105 | Button | Edit my opening and visit date |
| 110 | Button | Add |
| 116 | DisclosureGroup | If we have time · \(session.questions.count - 3) more |
| 126 | SourceLink | These are your recollections. Proposed care updates still need review. |
| 130 | Button | Remove this appointment companion |
| 141 | Button | Remove question and draft |
| 144 | Button | Remove companion and drafts |
| 152 | Button | My short opening brief |
| 153 | Button | Dynamic / supplied by parent |
| 166 | Button | Edit |
| 168 | Button | Dynamic / supplied by parent |
| 169 | Button | Dynamic / supplied by parent |
| 170 | Button | Dynamic / supplied by parent |
| 172 | DisclosureGroup | Where this question came from |
| 172 | SourceLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 135, `sheet` at 136, `sheet` at 137, `sheet` at 138, `fullScreenCover` at 139, `confirmationDialog` at 140, `confirmationDialog` at 143.

### VisitCompanionOpeningEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 197 | TextField | Appointment name |
| 198 | TextEditor | Your words start the short brief. This is personal context, not an extracted medical claim. |
| 199 | OptionalDateField | Dynamic / supplied by parent |
| 200 | Toggle | Synthetic practice |
| 203 | Button | Cancel |
| 204 | Button | Save |
| 209 | Button | Discard changes |
| 210 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 208.

### VisitCompanionAddQuestionView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 227 | TextField | What do I want to ask? |
| 228 | Button | Add my question |
| 237 | Button | Dynamic / supplied by parent |
| 246 | Button | Done |
| 249 | Button | Discard question |
| 250 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 248.

### VisitCompanionQuestionEditor

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 270 | TextEditor | This edits your visit copy. The original saved question and sources stay unchanged. |
| 271 | TextEditor | Dynamic / supplied by parent |
| 272 | Picker | My progress |
| 274 | Button | Cancel |
| 275 | Button | Save |
| 280 | Button | Discard changes |
| 281 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 279.

### VisitCompanionBriefView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 308 | Button | Read aloud |
| 312 | Button | Stop |
| 314 | ShareLink | Share my opening brief |
| 315 | Button | Create brief PDF |
| 320 | ShareLink | Share brief PDF |
| 325 | Button | Done |

### VisitCompanionLiveView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 367 | Button | Show my opening brief |
| 370 | TextEditor | Dynamic / supplied by parent |
| 374 | Button | Save answer |
| 376 | Button | We discussed this |
| 377 | Button | Ask this later |
| 379 | Button | Previous |
| 381 | Button | Next |
| 384 | DisclosureGroup | Saved context for this question |
| 391 | Button | Pause |
| 392 | Button | Dynamic / supplied by parent |
| 420 | Button | Save answers as evidence and review |
| 424 | Button | Finish and keep my drafts |

Presentation/search entry points: `sheet` at 395.

### VisitCompanionGuardedSourceLink

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 473 | Button | Dynamic / supplied by parent |

## CareInOne/Views/VisitPacketView.swift

### VisitPacketView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 25 | Button | Preview selected packet |
| 28 | Button | Track selected handoff |
| 32 | TextField | A question or priority for this visit |
| 33 | Button | Save to my visit questions |
| 42 | Toggle | Format as a message to my care team |
| 43 | Toggle | Include my name |
| 44 | Toggle | Include my date of birth |
| 45 | Toggle | Include my local contact |
| 46 | Button | Select suggested items |
| 47 | Button | Clear selection |
| 50 | Toggle | Limit recent changes |
| 51 | DatePicker | Saved since |
| 60 | Toggle | Dynamic / supplied by parent |
| 63 | DisclosureGroup | Review included details |
| 64 | SourceLink | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 78, `sheet` at 79.

### PacketPreviewView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 97 | ShareLink | Share selected text |
| 98 | Button | Create selected PDF |
| 103 | ShareLink | Share selected PDF |
| 107 | TextEditor | Dynamic / supplied by parent |
| 114 | Button | Done |
| 115 | Button | Done editing |

## CareInOne/Views/VisitWorkspaceView.swift

### VisitWorkspaceView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 21 | Button | Dynamic / supplied by parent |
| 23 | SourceLink | Dynamic / supplied by parent |
| 24 | Button | Add another source |
| 28 | NavigationLink | All questions |
| 29 | NavigationLink | Manage follow-through |
| 30 | Button | Delete workspace |
| 39 | Button | Delete workspace and its draft |
| 46 | Button | Edit title, encounter, or priorities |
| 47 | Picker | My progress |
| 51 | NavigationLink | Choose a visit packet |
| 52 | NavigationLink | Encounter and its sources |
| 58 | NavigationLink | What changed since \(checkpoint.title)? |
| 65 | Button | Dynamic / supplied by parent |
| 68 | Picker | Use an existing checkpoint |

Presentation/search entry points: `sheet` at 35, `sheet` at 36, `sheet` at 37, `confirmationDialog` at 38.

### ReadinessSections

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 90 | DisclosureGroup | \(kind.rawValue) · \(group.count) |
| 95 | SourceLink | Dynamic / supplied by parent |
| 96 | Button | Write an answer or edit question |
| 97 | NavigationLink | Compare the reports |
| 98 | NavigationLink | Review follow-through |
| 100 | Button | Save a clarification question |

Presentation/search entry points: `sheet` at 108.

### VisitDebriefView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 131 | OptionalDateField | Dynamic / supplied by parent |
| 133 | TextEditor | Dynamic / supplied by parent |
| 134 | TextEditor | Dynamic / supplied by parent |
| 136 | TextEditor | Dynamic / supplied by parent |
| 140 | Button | Save evidence and review |
| 144 | Button | Save draft and close |
| 151 | Button | Cancel |
| 155 | Button | Done editing recollection |
| 160 | Button | Save draft |
| 161 | Button | Discard these edits |
| 162 | Button | Keep editing |

Presentation/search entry points: `confirmationDialog` at 159.

## CareInOne/App/CareInOneApp.swift

### RootView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 66 | Button | OK |
| 83 | Button | Dynamic / supplied by parent |

Presentation/search entry points: `sheet` at 61, `fullScreenCover` at 62, `alert` at 65.

### LockedView

| Source line | Control | Label hint / dynamic context |
|---|---|---|
| 96 | Button | Unlock CareInOne |
