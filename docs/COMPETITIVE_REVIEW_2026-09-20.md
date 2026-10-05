# CareInOne competitive review — September 20, 2026

**Several products are serious competitors, and some already offer more breadth than CareInOne.** We should not claim that nobody comes close, that the category is new, or that we have demonstrated superior patient outcomes. Our opportunity is a coherent, patient-controlled workflow for preserving evidence, reviewing claims, keeping disagreements visible, and carrying unfinished work into the next visit.

This review examines 14 products and adjacent services using their official product pages, documentation, and an App Store listing. It is a desk review, not a hands-on comparative trial. Feature descriptions below are vendor statements unless explicitly identified as local code/test evidence. Unmentioned functionality is **unknown**, not absent. Clinical effectiveness, extraction accuracy, compliance claims, and adoption numbers were not independently verified. Prices and availability are snapshots, not purchase recommendations.

## Closest competitors

| Product | Publicly evidenced capabilities | Implication for CareInOne |
|---|---|---|
| **Guava** | Portal aggregation, document/photo lab extraction, tracking, search, trends, visit preparation, and iOS/Android access; advertises support for more than 20 languages. [Product](https://guavahealth.com/) | Closest broad comparator. Patient health organization plus visit preparation is already established. Our lack of live record connections and language coverage is material. |
| **My Medical Records.ai** | Upload/connect records, longitudinal timeline, record-grounded assistant, family profiles, custom reports, and selected records shared using expiring links. [Product](https://www.mymedicalrecords.ai/) Its iOS listing also describes visit recordings and transcripts contextualized with saved history. [App Store](https://apps.apple.com/us/app/my-medical-records-ai/id6757810301) | Direct overlap with capture, memory, and sharing. A transcript plus longitudinal AI is not a unique proposition. Selective export improves our workflow but does not equal revocable live sharing. |
| **PicnicHealth** | Gathers records, organizes history, offers a health assistant, and describes a clinical team that reviews records and develops care plans. [Product](https://picnichealth.com/) Its patient data page describes source-linked answers and control over record sharing. [Data access](https://picnichealth.com/own-your-data) | Strong competitor on reducing record-collection burden and explaining history. Its staffed clinical offering differs from our software-only scope; we should not imitate clinician recommendations. |
| **Medcorder** | Visit recording, synchronized transcript/audio playback, saved questions, reminders, and sharing with family. Its FAQ describes family rooms and conversation around recordings. [Product](https://medcorder.com/), [FAQ](https://medcorder.com/faqs/) | A strong benchmark for the recording-to-family-understanding journey. We have local evidence and playback, but no collaborative family room. |
| **Neatly** | Describes recording, visit summaries, AI questions, and a longitudinal conversation record on iOS and Android. Email/text sharing is described as available; direct caregiver and care-team collaboration is described as forthcoming. [FAQ](https://www.neatlyhealth.ai/faq) | Another close memory/capture comparator. Count announced collaboration separately from shipped functionality. |
| **JetHealth** | Advertises consent-based visit capture, structured medications/conditions/labs/follow-ups, caregiver updates, and longitudinal Apple-native health memory. Its public page invites users to early access. [Product](https://www.jethealth.ai/) | Particularly close positioning. Treat it as an early-access competitive signal, not proof that every advertised feature has been independently validated or broadly released. |

Guava also documents editable preparation summaries exported as PDFs, making usable visit output a baseline expectation. [Visit preparation](https://guavahealth.com/news/enhancing-doctor-visits-guava-ai-powered-auto-prep) Its listed premium price is $8 monthly or $78 annually; free functionality includes record/device connections and tracking. [Plans](https://guavahealth.com/plans) My Medical Records.ai lists a free tier and premium at $99 annually. [Pricing on product page](https://www.mymedicalrecords.ai/) CareInOne should compete on utility and reliability, not assume that alternatives require a costly subscription just to start.

## Important substitutes and adjacent products

| Product | Publicly evidenced capabilities/status | Implication for CareInOne |
|---|---|---|
| **Apple Health** | Medication and health-data organization; participating clinical records; health sharing and health-data export. [Apple Health](https://www.apple.com/health/), [Clinical records](https://www.apple.com/ca/healthcare/home-care/), [Sharing and export guide](https://support.apple.com/en-lamr/guide/iphone/iph5ede58c3d/ios) | Native integration and local privacy are not unique claims. We do not currently implement HealthKit or wearable synchronization. The main page's announced late-2026 redesign is not counted as shipped functionality. |
| **MyChart** | Results, messages, medications, scheduling, family access, and cross-organization views through Happy Together/MyChart Central. [Explore MyChart](https://www.mychart.org/l/en-us/explore/) | Do not portray it as only one institution's static record viewer. It supports real clinical transactions we cannot perform. Exact access depends on participating organizations and configuration. |
| **CareClinic** | Symptom/medication tracking, care diaries, reports, and caregiver-oriented workflows. [Product](https://careclinic.io/) | Daily tracking and reports are already well-served. Adding dozens of trackers would not by itself strengthen continuity. |
| **Bearable** | Custom symptoms, mood, medications and factors, correlations, timelines, and reports/exports. [Product](https://bearable.app/) | A focused benchmark for longitudinal self-observation. We should distinguish descriptive trends from causal or treatment claims. |
| **Medisafe** | Medication scheduling/reminders and dependent/Medfriend support. [Help center](https://help-center.medisafe.com/en/), [Medication scheduling](https://app.medisafe.com/tips/welcome/) | Specialized adherence workflows are more developed than our general follow-through reminders. Our app must not suggest that an extracted prescription is a clinically verified regimen. |
| **VisitRecall** | The current official site announces closure: recording stops September 30, 2026; export/delete access continues through December 31, with deletion afterward. It describes readable and JSON transcript exports. [Closure and export notice](https://visitrecall.com/manage-my-data/) | Do not list it as an expanding active competitor based on old pages. Its closure illustrates why offline access and usable exports matter; it does not establish anything about its previous accuracy or business causes. |
| **Abridge** | Enterprise clinical AI documentation spanning visit workflows and evidence-linked outputs. [Product](https://www.abridge.com/) | Adjacent benchmark for traceability, not a like-for-like consumer patient app. Source citations alone are not novel. |
| **Empirical Health** | Clinical care and biomarker-oriented health services. [Product](https://www.empirical.health/) | Adjacent alternative with a different operating model. Diagnosis, individualized treatment recommendations, and medical services remain outside CareInOne's intended role. |

## What the comparison supports

These are engineering/product judgments from the evidence above, not measured rankings.

| Patient job | CareInOne's current evidence | Assessment and remaining gap |
|---|---|---|
| Start with one small input | Typed/manual capture and review are exercised by simulator UI tests; no full chart is required. | Credible low-friction entry. Actual time-to-first-value still needs observation with patients. |
| Assemble records with little work | Photo/PDF/TXT/FHIR importers, local OCR, and source preservation have native tests. | Live portal retrieval is a major gap relative to connected alternatives. A FHIR file importer is not an EHR connection. |
| Remember a visit | Consent gate, recording/transcript/edit/playback and recovery paths exist. | Competing tools already serve this job. Physical audio routing, consent usability and real transcription quality remain unvalidated here. |
| Understand changing evidence | Reviewed claims, event/effective dates, exact quotes, provenance, duplicate handling and persistent discrepancies have deterministic tests. | Strong candidate for differentiation, but competitors' internal data models and conflict behavior are not established by public pages. No exclusivity claim is justified. |
| Keep unfinished work visible | Explicit test/referral/follow-up/procedure/admin state machines, honest missing-completion language and local priorities are tested. | Does not check outside systems to discover completion or book anything. The patient still supplies evidence. |
| Prepare for a visit | Existing questions/brief plus the new selected packet, prior-encounter follow-through and outgoing message draft. | Closes a practical gap found in our own implementation. Still needs clinician/patient usability review and shorter-output tuning for complex records. |
| Help a caregiver | Chosen text/PDF exports and selected source evidence. | Static copies only. No shared live profile, roles, access expiry, remote revocation, or collaboration notifications. |
| Keep records through an outage | Local SwiftData graph, protected source files and encrypted backup/restore have tests. | Backup is user initiated, attachments are bounded to 40 MB, and there is no automatic cross-device synchronization. A lost phone without a backup still loses local records. |
| Get semantic assistance | Generic compatible/OpenAI/Kimi adapters, schema/quote validation and optional consent exist. | Live provider quality, latency and cost have not been evaluated with funded credentials. Local extraction is intentionally bounded. Do not call it clinically validated AI. |
| Use it across circumstances | Native iOS 18+ with standard SwiftUI controls. | No Android/web patient client or full localization. Accessibility and real-device checks remain incomplete. |

The defensible product statement is:

> CareInOne turns patient-captured evidence into a reviewed, source-linked care memory, helping patients see changes, unresolved differences, and unfinished work, then choose what to carry into their next visit. Core care memory remains usable on the iPhone without cloud analysis.

We should demonstrate that behavior with difficult examples instead of claiming the most features, medical correctness, automatic conflict resolution, or a uniquely private architecture.

## Improvements implemented from this review

| Change | Patient benefit and boundary | Code and verification |
|---|---|---|
| **Selected visit packet** | Choose questions, discrepancies, tasks, changes, medications/allergies and optional personal notes. Preview the exact text/PDF before sharing. | `CareInOne/Core/VisitPacket.swift`, `Views/VisitPacketView.swift`; core selection/provenance tests, native PDF test and UI workflow test. |
| **Keep disagreements together** | A medication/allergy entry includes its differing accepted reports rather than presenting one dose as the winner. Preserves quotes, locations, uncertainty and patient edits. | `VisitPacketBuilder`; medication discrepancy packet regression. |
| **Carry older unfinished work forward** | A new appointment may have no source documents yet. Open work from earlier encounters now remains visible in preparation and in the packet. | `Views/PatientWorkflowViews.swift`, `VisitPacketBuilder`; future-encounter regression. |
| **Separate information selection from identity fields** | Name, DOB, contact and standalone personal notes start unselected. Selected evidence can itself contain identifying text, so the preview explicitly calls that out. | `VisitPacketView`; profile/notes exclusion regression. This is selection, not automatic de-identification. |
| **Care-team message draft** | Turn the selected packet into an editable message without a model call. Editing changes only the outgoing copy; regenerating the packet uses saved evidence. | `VisitPacketView`; UI test verifies editing removes the stale PDF share action and does not alter the next generated snapshot. Nothing is sent automatically. |
| **CareInOne throughout current product surfaces** | Consistent source folder, package, app target, Xcode project/scheme, setup, exports and release copy. | `CareInOne.xcodeproj`, generator, release preflight. Compatibility keys are documented in `BRAND_COMPATIBILITY.md`; existing storage and backup identities are retained. |

The new packet does not upload evidence, create cloud accounts, grant another person app access, or choose a medically correct instruction. It uses the same accepted local state and source boundaries as the rest of the app. The complete brief and encrypted full backup remain separate export choices.

## Next work, in priority order

The review also drove a second implementation pass: connected visit workspaces, named care checkpoints, saved-information comparisons, structured patient recollections with separate unanswered questions, evidence-readiness checklists, and previews of locally reconciled acceptance/deletion. These keep reviewed evidence connected across preparation and follow-through without a model call. Source deletion purges copied checkpoint evidence, and a task disappearing is not presented as completion. The exact scope and completed automated verification are in [the continuity plan](CONTINUITY_IMPROVEMENT_PLAN.md) and [implementation status](../IMPLEMENTATION_STATUS.md). These additions are not evidence of an industry-first combination or measured superiority.

The primary pages for Guava, My Medical Records.ai and PicnicHealth were rechecked during this implementation pass. The assessment remains: substantial competing functionality is already available; provider connectivity and live family/caregiver access are material gaps for CareInOne. No competitor trial account was created and no patient data was submitted.

1. **Measure the core patient journey.** Observe 5–10 people using synthetic records: first capture, review, discrepancy, next-visit packet and recovery. Record abandonment, corrections, confusing language and time. Do not substitute feature counts for usability evidence.
2. **Complete release validation.** Real iPhone recording interruptions, notification delivery, locked-device file access, VoiceOver/Dynamic Type, fresh installation, upgrade, encrypted restore and lost-device scenarios. Complete the live model evaluation before making accuracy claims.
3. **Reduce import effort without weakening consent.** A real provider connection needs supported organizations, authorization scopes, token lifecycle, revocation, pagination, versioned source preservation, reconciliation and failure recovery. Assess these against actual users' providers before selecting an integration vendor.
4. **Design caregiver access deliberately.** Determine whether chosen exports satisfy early users. If live collaboration is necessary, implement explicit grants, separate identities, expiry/revocation, audit, data lifecycle and synchronization conflict handling. This changes infrastructure obligations and cannot be honestly represented by a share button.
5. **Expand access using evidence.** Prioritize languages and devices requested by early users; verify OCR, dates, accessibility and clinical wording per locale. Do not expand medical recommendations or autonomous medication decisions.

## Comparative trial to run before claiming superiority

Use the same wholly fictional bundle in CareInOne and consenting test accounts for available competitors. Include two conflicting medication documents, a patient recollection, a scanned instruction, a conditional MRI mention, an explicit order, a linked result, an older unfinished referral and a future visit. Do not upload real patient data for this exercise.

| Task | Success observation |
|---|---|
| Add a brief typed recap with an empty profile | Useful reviewed information without reconstructing the chart first. |
| Import native PDF and scanned image | Original evidence survives and extraction errors can be corrected. |
| Add negated, conditional and family-history statements | No false patient diagnosis, order or medication instruction. |
| Add conflicting doses and a recollection | Both sources remain discoverable; patient confirmation does not erase document disagreement. |
| Import the same evidence twice | No unexplained duplicate medication or task. |
| Upload an older medical event today | Upload time is not treated as clinical recency. |
| Add an explicit test result | Only the matching work advances; absence of another result does not imply noncompletion. |
| Prepare for a new appointment | Earlier unresolved work and relevant questions remain accessible. |
| Share a narrow visit packet | Chosen information only, with conflicting quotes and a complete reviewable preview. |
| Disable cloud/network, relaunch, export and restore | Previously saved information remains usable and recovery is understandable. |

Measure task completion, median time, unsupported claims, false loop closures, provenance coverage, manual corrections and accessibility task completion. Log the exact version, subscription and enabled connections for each product. A missing permission or connection is not proof that the product lacks a feature. Have a second reviewer assess extraction/closure mistakes without knowing which product generated them.

**Current evidence does not include this head-to-head trial.** Repository tests demonstrate defined behavior in CareInOne; they do not establish superiority over other products or clinical effectiveness. Test results and remaining release limits are recorded in `IMPLEMENTATION_STATUS.md` and `docs/verification/`.
