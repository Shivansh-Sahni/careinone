# CareInOne: offline simulator walkthrough

The app works without a gateway or model key. Local extraction is deliberately conservative: it recognizes supported patterns rather than understanding arbitrary clinical prose. Use **Add a structured claim from this source** or **Manual** for information it does not extract. Accepted claims, not unreviewed suggestions, drive the care graph.

## Explore the loaded fictional patient

Start with the two patient companions:

1. **Today → Get ready for my visit** opens an appointment companion immediately. Edit your opening, reorder the first three questions, and add chosen questions from saved care. **My short opening brief** shows exactly what a clinician will see; it can be read aloud or shared as text/PDF.
2. **I’m at my appointment** shows one question at a time. Type `Allergy: latex` into an answer while practicing. Pause/resume, mark a question discussed or ask later, and move between questions. Drafts save after a short pause in typing; **Save answer** saves explicitly.
3. **Finish** provides before-leaving questions. **Save answers as evidence and review** preserves your recollections and opens the existing source review. Prompts are not treated as instructions. Accept an extracted claim only after checking it; My Care then updates.
4. **Today → Follow-through → Help me get this done** opens a saved task. Choose what is in the way. The message adapts automatically while unedited; replacing your edits requires confirmation. Copy it for a call or share through your chosen app. Nothing is sent automatically.
5. Set **My next small step** and a personal check-back time. This does not rewrite the clinical due date. On **Replies & progress**, record that you reached out, paste a reply, and choose **Save reply & review**. The message, reply draft, outreach history and reminder are local and recoverable.
6. If source corrections temporarily remove a task, find its paused helper under **Follow-through → Your saved next steps**. Review the source, then explicitly connect the preserved plan to the appropriate current care task. Source deletion, unlike correction, removes associated copied plans.

For your real visit, turn **Synthetic practice** off in the companion creation form or opening editor. Questions copied from demo evidence retain their labels. Mixed real/demo answers are not combined into one removable source; use a separate practice companion. In an empty patient, the same appointment flow starts with three editable, general conversation questions.

- **Today:** open a change, a discrepancy, or a follow-through item. Every item links back to evidence.
- **My Care → Medications → Metoprolol succinate:** compare the two documented doses and the separate patient report. The app does not pick a clinical winner.
- **Records to clarify:** add a resolution note, mark clarified, include clarified items, and reopen it.
- **Follow-through:** inspect requested tests, referral, procedure, result discussion, and administrative work. Add a note/date or mark completed by user report. A completed lipid-panel example demonstrates evidence-based closure.
- **Visits:** open the upcoming primary-care encounter or prepare a general visit brief.
- **Visits → Prepare for your next visit → Choose a visit packet:** select evidence to carry, add a visit priority, and preview the chosen text/PDF. Prior-encounter unfinished work remains available. Name, DOB, contact and standalone notes start unselected; source quotes can still contain identifying text. Turn on **Format as a message to my care team** to edit the outgoing copy without a model call. Draft edits are not saved to care memory; share or copy them before closing the preview.
- **My Care → Personal notes:** create, edit, search, or delete personal context without turning it into a clinical claim. Notes stay accessible even when their linked care item is removed.
- **Questions:** create/edit a question, record an answer, and include answered items.
- **Trends:** compare the fictional hemoglobin values. Units are kept separate.
- **Sources:** inspect original text, accepted claims, history, and source metadata; edit or delete a source and watch derived care rebuild.

## Connect preparation to what happened afterward

This flow works with the existing demo or with an empty local patient. Use fictional text while practicing.

1. Open **Visits → Visit workspaces → Start a visit workspace**. Name the visit and optionally link an encounter; add your personal priorities.
2. Choose **Save my starting point**. Give the checkpoint a name. It remembers currently reviewed reports, discrepancies and follow-through; an empty starting point is valid.
3. Open **Choose a visit packet** to select what to carry and preview/export the exact copy. The checklist lower in the workspace includes earlier unfinished work, unreviewed evidence and your questions.
4. After the visit, choose **Capture what I remember**. Leave the date unknown unless you know it. In **What I heard**, try `Allergy: latex`. Add any remaining questions one per line in their separate field.
5. Choose **Save draft and close** to continue later, even after relaunch. Choose **Save evidence and review** when ready. Recollections become patient-reported sources; questions stay separate. If only questions are entered, they are saved without creating an empty source.
6. In the saved source, open **Review & edit**, correct the proposal, and confirm that it reflects what was reported. **Preview changes to my care** runs the actual local rules on a temporary copy. Close the preview and accept when satisfied.
7. Return to the workspace and open **What changed since…?** New reviewed reports, changes to discrepancies and follow-through appear with before/after evidence and source links. An older medical event uploaded today is labeled new saved information, not a new medical event.
8. Choose **Preview comparison for export** for readable text or PDF. Review all included details before sharing.
9. Set **My progress** when useful. It describes your preparation workflow; it never marks a medical task completed.

**Care checkpoints** also opens directly from Visits. Rename or delete a checkpoint there. Deleting a source now opens a deletion-impact preview before confirmation. Deleted evidence is removed from saved checkpoints too; comparisons state that their coverage is incomplete. A vanished task or discrepancy is not labeled clinically completed or resolved.

## Explore evidence intelligence and tracked handoffs

All of these tools run locally without a model key or additional API costs.

1. Open **My Care → Care connections → Evidence map**. Choose **Metoprolol succinate** in the demo. **Where it comes from** traces reviewed reports back to original sources; **What it informs** shows connected discrepancies and workflows. Open a connected item to continue the trace. Each arrow is an information relationship, not clinical causality.
2. In **Two-date timeline**, switch **Order by** between medical event, effective date, added here, and reviewed here. A source can arrive long after an event; unknown dates have their own section. This shows current reviewed versions, not every historical edit. Source capture dates are never substituted for unknown medical dates.
3. In **Leave sources out**, select one or several sources and choose **Preview without selected sources**. The actual reconciliation rules run on a temporary copy. Inspect records, discrepancies or tasks that would no longer have support. Nothing is saved or deleted; disappearing disagreement does not mean it was resolved. Clear the preview to start again.
4. Open **Visits → Tracked handoffs → Choose a new handoff packet**. Select packet items, then **Track selected handoff**. Add a label and optional intended recipient. This saves locally; it sends nothing.
5. Open **Review exact outgoing copy** and inspect the selected text before sharing its text or PDF. The copy identifier is a SHA-256 digest, not proof of authorship, medical accuracy or delivery. Use **I shared this copy** only to record your own action.
6. Use **Add a reply or recollection**. For practice, enter `Allergy: penicillin` while using the demo. Choose the synthetic-material toggle if it is fictional. **Save draft** preserves text, date and the synthetic choice for relaunch. **Save reply as evidence** preserves the original text and runs extraction; it does not accept claims.
7. Review and accept the proposal in its source. Return to the handoff to see relevant changes since the outgoing copy. Source metadata and newly reviewed source content are watched even if re-analysis changes care-item identities. Use **Choose an updated packet** for a new selected copy; the original handoff is not rewritten.
8. **Mark handoff finished** records only your organizational progress. It never closes care tasks or discrepancies. New evidence remains visible under **Since you finished this handoff**, and you can reopen it.
9. Deleting any source quoted or otherwise included in a handoff removes the entire local outgoing text copy and clears locally prepared exports. The handoff explains the missing coverage. Copies already shared outside the app remain independent. Deleting a handoff itself preserves replies already saved as sources.

For a fresh patient, start with only a visit question: add it in the packet's priority field, save it to questions, and track that selection. No prior medical records are required. An unrelated reply still appears as a linked source; it does not silently broaden the handoff's selected care-item scope.

Limits: 100 handoffs; 2 million combined outgoing/draft characters; 200,000 characters per outgoing copy; 30,000 per reply draft; 50,000 combined comparison fingerprints. The evidence trace shows at most 200 nodes across six steps with explicit truncation. Omission previews accept up to 30 sources.

## Exercise the real file pipeline

1. Open **Settings → Practice text, PDF, photo & FHIR imports**.
2. Choose **Import and review** for a practice file. TXT, PDF, PNG, and single-patient FHIR JSON are available.
3. The app preserves the original, performs native text extraction/OCR or supported FHIR parsing, and shows editable source context.
4. Choose **Save evidence & review**. Review proposals individually; consequential claims require confirmation.
5. Accept a claim and inspect it in My Care, changes, search, and the related workflows.
6. Import the same bytes again to exercise duplicate detection.

These files contain fictional data and imported sources carry a synthetic flag. **Save sample to Files** lets you exercise the ordinary file picker too. When importing a separately saved sample through the ordinary picker, its title still identifies it as synthetic, but the app cannot infer its origin; delete that source individually after practicing.

## Start with a new patient

This version stores one local patient's care memory. To preserve the current records, create and save an encrypted backup first.

1. **Settings → Backup & restore:** enter a unique passphrase of at least 12 characters, repeat it, create a backup, then save it to Files.
2. **Settings → Delete all local data:** confirm the deletion. This returns to short onboarding and clears local gateway credentials.
3. Start empty, give an optional name, and add one typed note or manual entry. No full history is required.
4. For a simple local extraction example, type `Allergy: latex.` Save, review, confirm the report, and accept.
5. For detailed medication information, choose **Manual** and fill name, action, value, numeric value/unit, route, frequency, form, and known dates. Leave unknown dates unset.
6. Reopen the app to confirm persistence. Load the demo again from Settings whenever desired.

## Import and export

- Global **Add → PDF/File** imports PDF, plain text, images, and JSON. **FHIR** narrows the picker to JSON. Files can also be opened into the app from the system.
- **Photo** uses the photo picker. **Camera** requires a physical camera; the simulator explains its unavailability.
- A source's **Export original file**, **Prepare original text export**, and **Export saved audio** use the native share sheet. Availability reflects what was actually retained.
- **Care Brief** exports readable text or a paginated PDF.
- **Visit packet** exports selected items only; differing medication/allergy reports stay together. A shared file is a static copy, with no remote revocation or ongoing account access.
- **Settings** exports the care graph as readable JSON. This is an inspection/interchange export, not the restore format.
- **Backup & restore** creates an authenticated encrypted archive with original files and optional audio, then previews and restores it after confirmation. Restore replaces the current patient; it does not merge histories. The attachment limit is 40 MB. Keep the passphrase separately.

## Environment limits

No live LLM service is configured or required for these steps. Arbitrary-language synthesis/extraction needs optional cloud configuration. Camera, reliable microphone/on-device Speech availability, device authentication, and real notification/calendar permissions need physical-iPhone validation. There is no cross-device sync or dedicated share extension. Public distribution still requires signing, backend deployment if desired, and release validation.
