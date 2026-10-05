# Ordinary editor recovery — October 4, 2026

The previous question, note and encounter sheets could dismiss unsaved input without the confirmation already present in other app workflows. Each now retains an immutable saved original, prevents dirty interactive sheet dismissal, and offers **Keep editing** or **Discard changes** on explicit Cancel. Discard never writes the draft. Successful persistence still precedes dismissal, so a storage failure leaves edits available to retry.

Question answers and personal notes now use the shared system-paste/multiline editor and keyboard Done control. Encounter and question-title fields dismiss their keyboard explicitly. Personal-note deletion has a separate confirmation; deleting a note never deletes source evidence or reviewed care.

## Evidence

| Check | Result | Boundary |
|---|---|---|
| Swift syntax parse | Passed | Not runtime verification |
| Generic iOS Simulator Release build | **BUILD SUCCEEDED**, exit 0 in [editor-release-build.log](editor-release-build.log) | Separate temporary DerivedData; no simulator launched; later unrelated source changes require another build |
| `EditorRecoveryUITests`, Candidate3 | All three failed on prior source | Notes/questions never reached editors because helper omitted SwiftUI List collection views; encounter reached dirty discard but platform dialog omitted custom cancel-role Keep editing. Explicit two-action alert and bounded collection-view/keyboard-aware gestures now applied |
| [EditorRecovery4](editor-recovery4-summary.json) | One passed, two failed on disposable iPhone 18 Pro / iOS 27.0 | The 30-line Unicode note case passed paste/save/Keep/discard/relaunch preservation. Question was blocked by the expected saved notice; test now asserts/dismisses it. Encounter immediate keyboard-count assertion failed; a bounded keyboard-absence wait is required to distinguish AX transition from a real focus issue |
| [EditorRecovery5](editor-recovery5-summary.json) | **All three passed**, exit 0, disposable iPhone 18 Pro / iOS 27.0 | Note multiline Unicode paste/save/Keep/discard/relaunch, encounter keyboard Done and grouping preservation, question dirty dismissal/save/relaunch/Keep deletion/confirmed permanent deletion/relaunch all passed. Three invalid-frame warnings and a post-test 600-second diagnostic-collection timeout are disclosed. Full Candidate4 remains separate |
| [EditorRecovery6](editor-recovery6-summary.json) | Two passed, one failed | Question and encounter complete preservation flows passed after transient navigation-bar test repair. Note stopped at an immediate keyboard-count assertion; the same keyboard absence check now has a bounded five-second wait |
| [EditorRecovery7](editor-recovery7-summary.json) | One failed by test-runner timeout | AX lookup stalled after the generic content helper scrolled while locating the keyboard toolbar. This is no completed note pass. EditorRecovery8 verifies the same Done/Keep/discard/relaunch assertions with a bounded toolbar wait and native tap, without scrolling the editor to reach a keyboard toolbar |
| [EditorRecovery8](editor-recovery8-summary.json) | **One passed, zero failures**, finalized result | Complete 30-line Unicode note paste/save/Done/Keep/discard/relaunch/clean Cancel passed with toolbar-specific test navigation. One invalid-frame runtime warning is disclosed. Finalization required stopping only the confirmed idle owned post-test diagnostic collector after assertions ended; no app/active test/other device was stopped |

Root subsequently reproduced an iOS 18 system-paste callback crash on a small-screen simulator. Capture owns the shared editor repair. The Release build above does not close that minimum-supported-OS runtime issue, and these recovery tests must be rerun on the repaired candidate.

Force-killing the app with an unsaved ordinary editor is not described as automatic draft recovery. The controls protect deliberate in-app dismissal; previously saved data remains the recovery point.

Candidate3 failure contexts are in `/private/tmp/CareInOneCandidate3.log` (21:18–21:21 EDT). Its source snapshot predates these repairs. Dirty Cancel now presents an alert with explicit Keep editing/Discard changes on phone and iPad; destructive note/grouping confirmation remains separate. No assertion was removed to manufacture a passing result. The question test explicitly verifies and dismisses the real saved notice before proceeding; keyboard disappearance receives a bounded wait for the accessibility transition. Historical focused passes do not supersede later unresolved test-runner or full-candidate failures.
