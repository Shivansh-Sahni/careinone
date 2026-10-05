# Repository image credential screen

The Git-eligible PNG/JPG snapshot contained **47 pictures**: the app icon, provisional store captures and historical/focused verification evidence. macOS Vision accurate English OCR successfully processed all 47, with **zero request failures and zero recognizable credential-pattern matches**. No picture was flagged, so no additional visual review was performed. [Machine-readable counts, filenames, hashes and scope check](git-eligible-image-ocr-check.json)

Recognized text stayed only in memory. No recognized content, credential values or matched strings were printed, written to a log or serialized. The temporary audit script/output logs are under `/private/tmp/CareInOneGitEligibleImageOCR*`. User attachment paths and ignored raw screenshots, result/diagnostic bundles and archives were not read. No source, picture, asset, simulator or production service was changed.

The first sandboxed Vision requests and a CPU-only sandbox retry failed; they establish no secret-absence evidence. An approved repo-only local OCR operation outside the sandbox then completed successfully. The failed attempt remains private diagnostic evidence rather than being relabeled as a clean scan.

Patterns included provider/Render/GitHub/Google/Slack key prefixes, named gateway/Bearer tokens, private Render deploy hooks, JWT prefixes and a conservative mixed-case/digit long-token heuristic. OCR/pattern matching can miss low-resolution, obscured, split or unfamiliar credentials and can produce false positives. Zero matches does **not** prove an image contains no secret or patient data, and does not approve screenshot layout or provenance.

The recorded post-scan check compares currently eligible filenames and file hashes with the scanned snapshot. Any changed/new image requires another bounded screen before staging. Root's final store captures and visual review remain separate; this snapshot is not proof that final App Store assets are complete.
