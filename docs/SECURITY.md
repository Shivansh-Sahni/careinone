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

## Gateway

- HTTPS is mandatory in the iOS cloud adapter and provider adapter; redirects are rejected to prevent bearer-token forwarding.
- Tokens are administrator-issued, random, per-installation credentials. Hash comparisons use constant-time comparison. Never embed a shared production token in source control or an app build. There is no automated account enrollment service in this initial deployment model.
- Authenticated rate limits are bounded per configured token. Per-process in-flight concurrency is bounded; use reverse-proxy/global rate limits when scaling workers or replicas. Health is a content-free unauthenticated endpoint.
- JSON parsing rejects duplicate keys and non-finite constants. Input is capped at 1.2 MB/200,000 text characters, extraction at 200 proposals, provider responses at 2 MB, request upload at 15 seconds, and overall analysis at 180 seconds.
- Cancellation stops queued/async work. An already-started standard-library provider HTTP request may continue until its 45-second transport timeout because Python thread cancellation cannot stop a running socket operation. Its result is discarded; no patient state is changed.
- No CORS-enabled browser client is provided. Request-specified URLs and remote-fetch tools are not supported. Provider endpoint configuration is an administrative trust boundary.
- Access logging is disabled in supplied run/container commands. Exception responses are generic and never echo input/provider content. Infrastructure, tracing agents, proxies, crash reporting, and model-provider retention must also be configured appropriately before any real deployment.
- The container runs as a nonroot user, copies only application code and locked dependencies, and excludes local credentials. Run it with a read-only filesystem and a small ephemeral `/tmp` if supported by your host.

## Before distribution

- Configure signing, bundle ID, privacy policy/support URLs, deployment credential enrollment/rotation, TLS, model-provider agreements/retention, and App Store privacy answers for the actual deployed system. The included privacy manifest covers the source tree; it is not a substitute for deployment-specific disclosure.
- Validate Data Protection, backup exclusion, lock-screen/app-switcher behavior, file import permissions, consent, microphone interruptions, notifications, accessibility, and deletion on a physical iPhone using `VALIDATION.md`.
- This implementation has automated safety-boundary tests; it has not undergone an independent penetration test, clinical usability study, regulatory assessment, or medical-device certification.
