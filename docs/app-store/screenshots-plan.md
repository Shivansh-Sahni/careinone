# Release screenshot plan

Capture from the final candidate using the isolated fictional demo. The screenshots must show functioning screens, not an invented design or medical outcome. No real patient, token, API key, support correspondence or Simulator/macOS chrome belongs in store assets.

Use one accepted large-iPhone portrait size consistently and one accepted 13-inch iPad size. Source device captures must be PNG/JPEG without transparency. Current Apple specifications accept iPhone 6.9-inch portrait 1260×2736, 1290×2796 or 1320×2868; 13-inch iPad portrait 2064×2752 or 2048×2732. The target includes iPad, so a phone-only set does not close asset requirements. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

The iPhone 18 Pro is in Apple's 6.3-inch screenshot group. Its captures alone do not satisfy the required large-iPhone group. Use a supported 6.9-inch device, or Apple's documented 6.5-inch alternative if no 6.9-inch set is provided. Current requirement evidence is saved in [the dated upload audit](../verification/2026-10-04/release/APPLE_UPLOAD_REQUIREMENTS.md).

| Order | Native screen | Patient value shown | Optional truthful caption |
|---|---|---|---|
| 1 | Today in fictional demo | Upcoming visit, unfinished follow-through and recent evidence in one place | See what needs your attention |
| 2 | Source review with visible supporting quote | Compare a proposed detail with its preserved source before accepting it | Keep the source beside the detail |
| 3 | Medication discrepancy | Competing reported instructions remain visible and can be clarified | Bring conflicting reports to your care team |
| 4 | Appointment companion | Opening summary, selected questions and saved answers | Go into a visit prepared |
| 5 | Selected visit packet preview | Choose which care details and notes to share | Share the context you choose |
| 6 | Follow-through helper | Editable message, obstacle and check-back, with user-controlled sending | Make the next step easier to finish |

Capture these only when the actual final UI path succeeds. If a caption would cover evidence, increase visual complexity or imply a feature beyond the build, submit clean native screenshots. Do not use “never seen before,” “clinically proven,” “complete medical record,” autonomous delivery, guaranteed safety or comparative superiority claims.

Before delivery, inspect each PNG's native dimensions/color channels and visually inspect iPhone/iPad layouts, including modal controls, long labels and clipping. Record file names, build number, device/runtime and fictional workspace. Pending production cloud access is not evidence for a successful real-AI screenshot. Optional-cloud setup is a private review path, not a marketing screen containing a credential.


## Final native capture paths

The parent owns simulator capture after the final source freeze. Use the following two directories relative to the repository and preserve the original device pixels:

- `docs/app-store/screenshots/iphone-6.9/`
- `docs/app-store/screenshots/ipad-13/`

Use the same ordered filenames in each directory:

| File | Capture state |
|---|---|
| `01-today.png` | Fictional demo Today, no open keyboard or transient success alert |
| `02-source-review.png` | A real pending proposal with its supporting fictional quotation visible |
| `03-medication-reports.png` | Medication detail with competing reviewed reports clearly labeled |
| `04-appointment-companion.png` | Selected fictional visit with opening summary/questions |
| `05-selected-visit-packet.png` | Actual generated PDF preview from selected fictional content |
| `06-follow-through.png` | Editable next-step assistance with no sending/authentication claim |

If the final demo has no pending source proposal, import one of the packaged fictional samples and stop at its real review screen; never fake a pending state or use a failed model run. If one path remains unresolved, omit that marketing screen and record the reason; Apple requires at least one screenshot in each required group, not all six proposed screens.

Record `docs/app-store/screenshots/capture-manifest.json` after capture, including app version/build, final source revision, Release configuration, simulator model, runtime, native pixel dimensions, file SHA-256, capture date, and confirmation of isolated fictional data. No device UDID, credential, real patient identifier or private account details need be recorded. A file passing pixel checks alone does not establish usable layout: visually inspect each native image before upload.

Run `python3 docs/app-store/verify-screenshots.py` after capture. It validates PNG signature/IHDR, accepted device-group portrait or landscape dimensions, no alpha channel, and file hashes. A missing group is explicitly pending, not a passing release asset result. If JPG assets are selected instead, use an appropriate image inspector and record equivalent checks; this script intentionally handles only the planned PNGs.
