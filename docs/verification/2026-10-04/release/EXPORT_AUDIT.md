# Export and sharing repair audit

Updated October 4, 2026. All added test records are fictional. Implementation is complete in the source tree; all eight native export safety tests passed in the finalized Candidate4 run. Final outgoing-message UI and physical destination/accessibility checks remain separate.

## Findings and repairs

| Finding | Repair | Evidence required |
|---|---|---|
| Exporting twice reused a shared filename, which could change the bytes behind an earlier share URL | Every file preparation gets a separate protected UUID directory while retaining a readable filename | New repeated graph/PDF preparation tests |
| A PDF could remain offered after its preview was edited or care records changed | Prepared PDF stores the exact UTF-8 content digest; share is offered only for matching current text and a readable file; mutable previews invalidate the old copy | New exact multiline/Unicode binding and deletion tests; UI follow-up |
| Care-brief PDF used a footer claiming patient review even when sources were unreviewed | Neutral “Shared care information” footer | PDF text assertion |
| Old chunking trimmed text and divided pages without respecting rendered layout | CoreText paginates the full attributed string using visible UTF-16 ranges; all evidence rows are retained | 3,200-row PDFKit inspection |
| Very large PDFs could occupy unbounded rendering time or silently omit later text | One-million UTF-16-unit and 200-page bounds reject clearly, offering text sharing or fewer selected items | Empty, character-bound and page-bound rejection tests |
| Packet preview editing left the keyboard obstructing share controls | Explicit keyboard Done editing action, focus dismissal before PDF preparation, interactive scroll dismissal | Final simulator editor/share check |
| A failed PDF retry could leave an older share copy or previous error visible | Clear the previous preparation before attempting a replacement; clear old errors on new attempts/edits | Source inspection and final UI check |

The private writer rejects unsupported filenames and removes only its newly created directory after a failed write. Discarding one prepared snapshot removes its own directory, not another export. Graph and encrypted-backup formats are unchanged. Existing complete file protection and background-safe encrypted-backup writer are preserved.

## Changed source scope

- `CareInOne/Services/ExportService.swift`
- Only `CareBriefView` at the end of `CareInOne/Views/SettingsView.swift`; Settings and backup controls belong to the root task.
- Export sections of `HandoffViews.swift`, `VisitPacketView.swift`, `ContinuityViews.swift`, and `VisitCompanionViews.swift`.
- `IntegrationTests/ExportSafetyIntegrationTests.swift` (eight tests).

The capture task separately owns source-text-export invalidation and readable-file checks in `SourceViews.swift`. No simulator state, user care records, Keychain item, signing identity, or external share recipient was changed by this audit.

## Verification status

- **Passed:** Swift 6 native compile and all eight `ExportSafetyIntegrationTests` in [Candidate4](candidate4-summary.json), including actual PDFKit pagination, repeated file isolation, exact-content binding and bounded rejection. Generic iOS Release archive also succeeded ([audit](UNSIGNED_RELEASE_ARCHIVE.md)); it is unsigned and not uploadable.
- **Pending:** Final mutable care-brief/packet-preview UI tests, iPad share popover, native Files destination, and assistive-technology operation.
- Test fixtures do not create AppStore/SwiftData containers, schedule notifications, or touch gateway Keychain. Teardown removes each test's uniquely owned export directory.
- A visible share sheet is an outgoing preparation, not evidence that a clinic received or acknowledged information. Copies already shared outside the app cannot be recalled.

Parent owns final full-candidate reconciliation. Candidate4 had 20 passing UI cases and three failures, including outgoing-message editing; its overall failure is recorded honestly in the linked summary. Do not infer recipient delivery from successful file preparation.
