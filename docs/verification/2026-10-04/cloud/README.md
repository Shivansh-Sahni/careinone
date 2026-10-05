# CareInOne cloud verification — October 4, 2026

The current backend passes 108 unique automated tests on Python 3.14.3 and Python 3.13.7, plus the actual localhost HTTP smoke test using pinned runtime dependencies and Python 3.13.7. The public Render health endpoint returned HTTP 200. After the initial multi-claim failure, the parent deployed strict output repair 9f5e88bf9e6bc7c8b743a6c69249e48c23bc13b9 and verified both a real synthetic connection check and a separate three-claim fictional extraction with exact quotations. This subtask made no paid calls and retrieved no gateway token. The separate native source/review pipeline still requires verification after the saved simulator connection is restored; the attempted native check stopped before any paid request because its endpoint/token pair was unavailable.

## Repaired issue

The previous gateway accepted a provider API key as a model identifier and returned it in authenticated `/v1/config` metadata. This caused the visibly exposed key in the supplied simulator screenshot and made model requests fail.

The provider now rejects credential-like or malformed model identifiers before startup. It permits bounded ASCII model identifiers with letters, digits, periods, underscores, colons, slashes and hyphens, including pinned and namespaced models. It rejects common secret prefixes, JWT-like tokens, whitespace, quoted values and the actual provider key embedded in the model field. The same validation applies to fallback models and runs again before metadata disclosure. The gateway also rejects any configured gateway token embedded in a primary/fallback model, provider URL, or provider API key at startup and before metadata disclosure. It retains only token hashes and lengths for this check, rather than another plaintext copy. The verifier separately checks that returned model/host metadata does not contain its private gateway token; unsafe metadata stops verification before any model request.

Provider URLs reject spaces, controls, URL credentials, queries/fragments, invalid ports, credential-like hosts, actual key substrings, and an accidentally appended `/chat/completions`. Operator-controlled endpoint, key and model values are excluded from dataclass representations. Malformed numeric environment configuration raises fixed errors without echoing values. Gateway-token configuration rejects provider-key prefixes. Per-process rate and concurrency bounds cannot be disabled with invalid zero or Boolean values.

Provider failures now return an allowlisted `errorCode` with fixed recovery text. Authentication, permissions, wrong model/endpoint, insufficient quota, rate limits, unsafe output and general availability are distinguished without returning provider error messages, request bodies, URLs, tokens or patient content. HTTP status compatibility is preserved.

Schema repairs reject collection-valued enumerations consistently, reject enormous integers without numeric overflow, and normalize null attribution/confidence to explicit uncertainty. Escaped lone UTF-16 surrogates are rejected before provider/response encoding; complete Unicode, emoji and multiline evidence remain supported.

Disconnect monitoring now begins before model-capacity acquisition. An upload cancelled while queued cannot start a later billed request when a slot opens. JSON nesting is capped at 64 before decoding; brackets and escaped punctuation within source strings do not count toward that bound.

A shared thread-side limiter bounds actual compatible-provider transport operations to four per process, across primary and fallback provider instances. A cancelled HTTP worker keeps its slot until the socket finishes; cancelled waiting workers exit without dispatching a later model request. Waiting for transport capacity is bounded by the configured timeout, and worker failures release capacity. This repairs the earlier gap where cancelling an asyncio future released the gateway slot while a provider socket continued running.

Public `/privacy` and `/support` endpoints serve only the two reviewed UTF-8 HTML files. They accept GET and HEAD without app authentication; mutations return 405. Request paths, query strings, headers and bodies never choose or interpolate a file. Traversal and alternate file paths return 404. Documents have no-store, nosniff, no-referrer, DENY frame protection and a restrictive content security policy with no scripts, external resources or forms. The Docker context remains deny-all except exact runtime files and these public documents; no credentials, tests or general repository files enter that context.

## Evidence

| Evidence | Result | Scope |
|---|---|---|
| `backend-tests.log` | 108 tests passed | Existing boundaries plus 58 added configuration, disclosure, error, cancellation, concurrency, schema, public-document and Docker-context regressions |
| `backend-tests-py313.log` | 108 tests passed | Same suite on the deployment's Python 3.13 family |
| `http-smoke.log` | Passed | Real HTTP public privacy/support GET/HEAD, rejected mutations/traversal and security headers; startup, health, auth, extraction, configuration and synthetic check using fictional mock evidence |
| `public-health.json` | HTTP 200 | Public deployed health only; no claim of model readiness |
| `strict-output-live-result.json` | Both real requests HTTP 200 | Parent-operated server verification on deployed strict-schema commit; three fictional claims passed independent envelope and exact-quote validation |

Python 3.14.3 and Python 3.13.7 were used locally. The smoke test used the repository's pinned click/h11/uvicorn runtime in a temporary isolated Python 3.13 environment. The deployment image declares Python 3.13. Docker is unavailable locally, so container execution was not verified; exact Docker COPY sources, their existence and the deny-all context allowlist are covered by tests.

## Bounded live verification

`backend.verify_gateway` accepts the gateway token through stdin (`--token-stdin`) or the private `CARE_GATEWAY_TOKEN` environment variable. Never put a token in command arguments or a report. The default run reads health and configuration without model calls. Inside the deployed server only, explicit `--server-environment` reads the first configured `CARE_BACKEND_TOKENS` value internally, without exporting or printing it. Without this flag the operator token list is never used implicitly. The verifier is included in the deny-all Docker runtime allowlist. `--synthetic` makes one fixed synthetic model check; `--extract` makes one fixed fictional source extraction. At most two model-facing gateway requests are attempted; a configured fallback can increase provider attempts. Reports contain validated provider metadata and counts, never evidence, model output or credentials. Metadata from older unsafe gateways is rejected rather than printed. Mock success is explicitly not reported as live inference.

On the existing Render Web Shell, configuration can be checked without copying a token out of the service and without using model quota:

```text
python -m backend.verify_gateway --server-environment
```

Only after the configuration is correct, explicitly request the two bounded fictional model calls:

```text
python -m backend.verify_gateway --server-environment --synthetic --extract
```

Do not echo environment variables or paste secrets into shell commands. The server flag is mutually exclusive with stdin authentication. Automated tests assert that neither server token appears in stdout and that the default server verification makes only health/config reads, with zero paid requests.

Example after obtaining a token through a separate private mechanism:

```text
python3 -m backend.verify_gateway --token-stdin --synthetic --extract --output docs/verification/2026-10-04/cloud/live-gateway.json
```

## Account evidence supplied by the parent

The parent verified on October 4 that the current Apple account is Individual, its renewal is valid through October 4, 2027, and no signing certificates are installed locally. This is parent-observed account evidence, not a verification performed by this backend subtask. NutriAssist organization approval remains unconfirmed and is a publication dependency; active individual membership is not approval to publish under NutriAssist.

## Multi-claim live failure repair (parent observation at 00:38:30 UTC)

The simple connection check succeeded against the pinned gpt-4.1-mini-2025-04-14 primary; the separate fictional extraction failed validation. A failure of JSON-mode schema adherence is a plausible cause, not a confirmed diagnosis. The previous system prompt omitted optional primitive types and ambiguously asked for clarification questions while the wire schema accepts a single question string per claim.

The OpenAI adapter now requests strict JSON Schema with no additional keys, all fields typed, all optional fields nullable and all claim keys required. It does not change the model, maximum output tokens, retries, provider credits or service spending controls. The prompt explicitly describes nullable values, primitive field types, per-claim clarification and due-date constraints. Evidence validation remains strict: structured shape never bypasses exact quote matching or clinical uncertainty boundaries.

Safe validationCode diagnostics identify only fixed categories (for example quote_not_exact, date_invalid, enumeration_invalid, output_incomplete) without any offending value, provider text, key, quotation or credentials. The verifier preserves only allowlisted codes. The new offline tests cover strict request shape, null-bearing multi-claim fictional output, family/conditional/negated attribution preservation, exact-quote rejection and sanitized diagnostic propagation. Successful unit fixtures establish wire behavior, not real inference quality.

At 01:06:21 UTC on October 5, the parent ran the two bounded real requests from the existing Render server on commit 9f5e88bf9e6bc7c8b743a6c69249e48c23bc13b9. The primary remained gpt-4.1-mini-2025-04-14 at api.openai.com with 6,000 maximum output tokens, no fallback and 40,000 source characters. The connection check and separate three-claim fictional extraction both returned HTTP 200, and every returned quotation matched the fixed source exactly. The parent records four total server verification requests across the failed and repaired runs. This small sample confirms real transport/schema behavior, not a clinical-quality evaluation. No model/spending controls were changed for the repair.

## Remaining deployment work

- The parent deployed the repaired gateway and verified authenticated configuration plus the two bounded real requests. Retain the exact deployed-commit report rather than relying on a local build.
- Rotate any key exposed in prior screenshots if it is still active. No exposed key was used in this subtask; the parent owns the credential readiness evidence.
- Restore the simulator gateway endpoint/access-token pair privately, then verify source-to-analysis-to-review-to-saved-care in the native app. The initial native attempt consumed zero paid requests and its missing-config blocker is documented in the live report.
- Retain the current billing controls. Do not add credits merely to repair a configuration mistake.
- Public cloud enrollment remains operator-issued per-installation credentials. No shared production bearer token should be embedded in the public app. Local use remains independent of cloud enrollment.
- Per-process rate limits are not a global monthly financial cap. Existing provider spending controls and operational monitoring must remain in place.
- Thread cancellation discards a completed HTTP result but cannot interrupt a standard-library HTTP socket already running; it may consume provider quota until its transport finishes or times out. Four actual provider operations remain the process-wide ceiling while these workers finish. Original evidence and canonical state are not changed by a failed/cancelled request.

## Official API cross-check

OpenAI Structured Outputs with strict JSON Schema now constrains proposal keys, enum values and primitive types; optional fields are required-but-nullable as specified by OpenAI. Compatible/Kimi adapters retain JSON mode. The gateway still validates exact quotations, numeric ranges, lengths, dates and semantic date relationships independently. [Structured output documentation](https://developers.openai.com/api/docs/guides/structured-outputs)

The OpenAI adapter uses Chat Completions with `max_completion_tokens` and `store: false`. Storage opt-out does not by itself establish Zero Data Retention or eliminate abuse-monitoring retention; deployment-specific disclosures and agreements must reflect the actual account. [Chat Completions reference](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create), [data controls](https://developers.openai.com/api/docs/guides/your-data)

This evidence is an engineering verification record, not a clinical-quality evaluation, penetration test or App Store approval.
