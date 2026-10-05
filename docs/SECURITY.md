# Security and privacy decisions

## Trust boundaries

1. **Original evidence is untrusted input.** Files have bounded sizes and supported types. FHIR is parsed as JSON, not executed. Text within a source never becomes an instruction to execute tools or change state. Images/PDFs use system decoders; locked or failed extraction preserves the original and reports the limitation.
2. **Model output is untrusted input.** The wire schema has no source/entity IDs, accepted status, canonical state, or supersession links. Unknown fields, invalid values, and quotes absent from evidence are rejected. The Swift client rebuilds its own IDs and validation. Explicit source conditionality/family language cannot become a safe high-confidence claim solely because the model says so.
3. **The patient review transaction is the canonical gate.** Consequential claims require individual confirmation. Weak entity matches never auto-merge. A patient edit is recorded as patient editing, not clinician verification.
4. **The iPhone is the persistent health-data owner.** The gateway holds text only for bounded request processing. It has no PHI database, filesystem cache, upload bucket, or persistent patient session.

## Local data

- SwiftData and the evidence vault live in a dedicated Application Support directory with complete iOS Data Protection and backup exclusion. The entitlement sets default file protection. No iCloud/CloudKit capability is enabled.
- Original evidence and database payloads are health information. Protection is supplied by iOS and the device passcode; no claim of a separate cryptographic database layer is made.
- Backend token/URL are stored together as one atomic Keychain item with `WhenUnlockedThisDeviceOnly`, preventing partial preference writes from pairing a token with a different endpoint. Provider API keys remain exclusively in backend environment/secret configuration. Credential deletion errors are surfaced rather than reported as success.
- Optional app lock uses `deviceOwnerAuthentication`, including device passcode fallback. Backgrounding relocks the app; inactive scenes are covered to prevent app-switcher snapshots of care information.
- Recording requires microphone permission and explicit per-visit confirmation. Recordings pause outside the foreground; no background recording entitlement exists. Interrupted drafts are retained locally for recovery. Audio may be deleted independently of text/claims.
- Local notifications have a generic app title/body, never names, medication labels, quotes, diagnoses, or appointment details on the lock screen. Calendar additions occur only from an explicit user action and request write-only calendar access.
- Export is explicit. Text/PDF/JSON export contains health information; external recipients and share destinations are selected by the patient. JSON export excludes binary attachments/audio. Temporary exports use file protection and can be removed with all-data deletion.
- Audit events contain only a fixed operation name, timestamp, and count. Application logging emits generic operational messages, never source text, provider output, tokens, names, or clinical labels.

## Evidence intelligence and handoff copies

- Graph traversal and multi-source omission run only over local values. Omission reconciles a copy off the UI thread and discards it if cancelled or if saved state/selection changes. It never mutates patient records or schedules notifications.
- Handoffs keep an immutable selected outgoing text copy, comparison hashes, explicit selected source/claim/entity references, organizational status and patient-authored reply drafts in the protected SwiftData payload. These are health data and are included in encrypted backup. Optional metadata preserves older store/archive decoding.
- Comparison hashes include canonical claims, relevant discrepancies/workflows, reviewed content and metadata of supporting sources, selected questions/notes and only profile fields explicitly included in the outgoing copy. Unreviewed model proposals do not become accepted care. Re-analysis can change entity IDs; source-content fingerprints still surface a change without silently merging identities.
- SHA-256 identifies a text copy; it does not authenticate its author or certify medical accuracy. Sharing is explicit through the system share sheet. Status reflects the patient's report, not recipient delivery, clinician acknowledgement or clinical task completion.
- Deleting a supporting source invalidates the entire copied outgoing text, prunes associated comparison references and clears local export staging after the database transaction succeeds. A failed save retains the prior copy and files. Deleting a handoff leaves independently captured reply sources intact. User-authored labels/drafts are independent context; source deletion cannot infer their origin. All-data deletion clears every handoff.
- Bounds: 100 handoffs; 2M combined outgoing/draft characters; 200K characters per outgoing copy; 30K per reply draft; 500 selected items; 50K combined comparison fingerprints, at most 10K per context. Restore validates identifiers, dates, digests, bounds and source references. The ordinary encrypted-archive bounds still apply.

## Gateway

- HTTPS is mandatory in the iOS cloud adapter and provider adapter; redirects are rejected to prevent bearer-token forwarding.
- Tokens are administrator-issued, random, per-installation credentials. Hash comparisons use constant-time comparison. Never embed a shared production token in source control or an app build. There is no automated account enrollment service in this initial deployment model.
- Authenticated rate limits are bounded per configured token. Per-process in-flight concurrency is bounded; use reverse-proxy/global rate limits when scaling workers or replicas. Health is a content-free unauthenticated endpoint.
- JSON parsing rejects duplicate keys and non-finite constants. Input is capped at 1.2 MB and defaults to 40,000 text characters (configurable up to 200,000), extraction at 200 proposals, provider responses at 2 MB, request upload at 15 seconds, and overall analysis at 180 seconds.
- Cancellation stops queued/async work. An already-started standard-library provider HTTP request may continue until its 45-second transport timeout because Python thread cancellation cannot stop a running socket operation. Its result is discarded; no patient state is changed.
- No CORS-enabled browser client is provided. Request-specified URLs and remote-fetch tools are not supported. Provider endpoint configuration is an administrative trust boundary.
- Access logging is disabled in supplied run/container commands. Exception responses are generic and never echo input/provider content. Infrastructure, tracing agents, proxies, crash reporting, and model-provider retention must also be configured appropriately before any real deployment.
- The container runs as a nonroot user, copies only application code and locked dependencies, and excludes local credentials. Run it with a read-only filesystem and a small ephemeral `/tmp` if supported by your host.

## Before distribution

- Configure signing, bundle ID, privacy policy/support URLs, deployment credential enrollment/rotation, TLS, model-provider agreements/retention, and App Store privacy answers for the actual deployed system. The included privacy manifest covers the source tree; it is not a substitute for deployment-specific disclosure.
- Validate Data Protection, backup exclusion, lock-screen/app-switcher behavior, file import permissions, consent, microphone interruptions, notifications, accessibility, and deletion on a physical iPhone using `VALIDATION.md`.
- This implementation has automated safety-boundary tests; it has not undergone an independent penetration test, clinical usability study, regulatory assessment, or medical-device certification.

## September 15 hardening

- Consent binds to the disclosed primary/fallback hosts and models. A changed or missing configuration ID returns HTTP 409 before provider forwarding. Save-only connection changes disable previous consent.
- OpenAI requests set `store: false`; that is not a promise about all provider retention. Kimi sampling is omitted to avoid incompatible fixed-temperature settings. Refused, tool-calling, and truncated responses are rejected.
- iPhone cloud responses are bounded while streaming, rather than only after downloading. Errors never echo server or model response bodies.
- Encrypted backups use CryptoKit AES-256-GCM and CommonCrypto PBKDF2-HMAC-SHA256 (600,000 iterations), random 32-byte salt, and a random GCM nonce. Passphrases and credentials are not archived. Input sizes, graph IDs, source links, and file references are validated before restore. New files stage under fresh names; failed persistence removes staged files and retains prior records.
- Successful restore resets cloud consent and notifications. Backup recovery has no password reset; external copies remain the user’s responsibility. See `RELEASE.md` for exact size limits and validation steps.
