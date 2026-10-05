# Lowest-cost launch without removing existing functionality

Prices checked September 15, 2026. All figures are USD before tax. This is an implementation and planning guide, not a claim that any untested model has equal extraction accuracy or that a public deployment has been completed.

## 1. Keep the existing local-first architecture

You do **not** need a large hosted patient database to launch this product as specified.

| Component | Implementation | Your usage-based cloud cost |
|---|---|---|
| Patient graph, history, questions | SwiftData on the iPhone | $0 |
| Original photos/PDFs/audio | Protected local evidence vault | $0 |
| OCR/PDF text extraction | Vision/PDFKit on device | $0 per API call |
| Supported voice transcription | On-device Speech | $0 per API call |
| Reconciliation, search, trends | Local Swift | $0 |
| Notifications | Local UserNotifications | $0 push provider fees |
| Export and encrypted backup | Local generation, user-selected destination | $0 hosted storage supplied by us |
| Optional semantic extraction | Stateless gateway → chosen LLM | Metered tokens |

Zero provider fees do not mean unlimited device storage, universal on-device Speech support, or free storage from a third-party backup destination. The app already preserves evidence and exposes retry/manual paths when local processing cannot finish.

Do not add a PHI database, vector database, managed OCR API, cloud audio storage, GPU instance, realtime voice API, or a second paid search service for capabilities the current application already performs locally. Navigation, search, conflict comparisons, and graph rebuilds must never trigger model calls.

Automatic cross-device synchronization is **not implemented** and is not equivalent to encrypted manual backup. If it becomes a product requirement, add it explicitly with encryption, key recovery, version/conflict handling, quota controls, and tested restores. The current backup has a 40 MB attachment ceiling; it is not an unlimited archival service.

## 2. Choose a model through measurement

For initial evaluation, use the existing OpenAI adapter with `gpt-4.1-mini-2025-04-14`. Compare it with `gpt-4.1-nano-2025-04-14` using the same synthetic source set. These are candidate configurations, not clinically validated defaults.

| Candidate | Input / 1M tokens | Output / 1M tokens | At 3,000 input + 1,000 output tokens per source |
|---|---:|---:|---:|
| GPT-4.1 mini | $0.40 | $1.60 | $0.0028 |
| GPT-4.1 nano | $0.10 | $0.40 | $0.0007 |

Standard uncached pricing: [official GPT-4.1 mini page](https://developers.openai.com/api/docs/models/gpt-4.1-mini), [official GPT-4.1 nano page](https://developers.openai.com/api/docs/models/gpt-4.1-nano). Account availability and future deprecations must be checked before pinning a production model.

Kimi remains supported using `CARE_PROVIDER=kimi`. Do not assume its name or “cheap” reputation makes it cheaper for this workload. Confirm your account’s input, output, cached-input, and reasoning charges from [Kimi pricing](https://platform.kimi.ai/docs/pricing/chat), then use the calculator’s custom rates. The publicly fetched pricing page did not expose a reliable numeric Kimi rate table during this review, so this guide does not invent one.

**Equal functionality is not equal extraction quality.** Compare medication dose/route/frequency, negation, conditional plans, family history, event dates, quoted evidence, and missed claims. A smaller model can return perfectly valid JSON while misunderstanding a fact or omitting it. Schema validation and error fallback do not detect every semantic failure. Do not silently replace semantic extraction with local rules just to save money.

Start with the cheapest model that passes a representative quality evaluation. Current code provides primary/fallback routing; fallback handles provider/schema failure, not proven semantic-quality detection. A larger model can still be configured as primary or fallback without changing the app.

The bundled runner compares eight synthetic regression cases against the primary model only, so a fallback cannot hide a weak primary. It reports schema failures, missing required claims, forbidden interpretations, and latency. It does not print model response text or use patient records. Running it consumes API quota:

```sh
.venv/bin/python -m backend.evaluate --list
.venv/bin/python -m backend.evaluate --model gpt-4.1-mini-2025-04-14 --output /tmp/care-mini-eval.json
.venv/bin/python -m backend.evaluate --model gpt-4.1-nano-2025-04-14 --output /tmp/care-nano-eval.json
```

Use an OpenAI-configured environment for those two model IDs. Configure Kimi separately before evaluating its model IDs. Eight cases are only an initial regression screen; expand to a representative, independently reviewed corpus and compare actual provider token usage before selecting a production model.

## 3. Host the existing container cheaply

**Lowest idle-cost candidate: Google Cloud Run with request-based billing and zero minimum instances.** It can run the existing Python container without a Workers rewrite. The published free tier includes 180,000 vCPU-seconds, 360,000 GiB-seconds, and 2 million requests monthly, based on us-central1 pricing. This is shared billing-account allowance, not a guarantee of a zero bill. Model-wait time can contribute to billed active instance time; registry, build, secrets, logs, and network charges are separate. [Cloud Run pricing](https://cloud.google.com/run/pricing).

**Low fixed-cost alternative: a Render paid Starter web service**, listed at $7/month for 512 MB. It fits the current container and avoids the free service’s intentional 15-minute idle spin-down. Verify pricing/account eligibility at checkout. [Render pricing](https://render.com/pricing), [free-plan behavior](https://render.com/docs/free).

Cloud Run scale-to-zero can delay the first request after inactivity. If consistent first-request latency is essential, set a minimum instance or choose always-on hosting and accept the extra cost. No honest recommendation can promise both zero idle compute cost and no cold-start tradeoff.

### Concrete Cloud Run setup

1. Create a dedicated Google Cloud project, attach billing, and choose a region appropriate for your users and data processing requirements. us-central1 is the example, not a universal residency recommendation.
2. Enable Cloud Run, Artifact Registry, and Secret Manager. Use a Docker repository named `careinone`. Enable Cloud Build only if you choose Google-hosted builds.
3. Create a service account named `care-gateway`. Grant it **Secret Manager Secret Accessor only on the two required secrets**, rather than project-wide administrator access.
4. Run `.venv/bin/python -m backend.configure` locally. Choose `openai` and the candidate model. Put `CARE_MODEL_API_KEY` into a Secret Manager secret named `care-model-key`; put the generated gateway token list into `care-installation-tokens`. Use the console or a protected secret file. Never put these values in the deployment YAML, git, or the iOS bundle.
5. Build from the repository root using `backend/Dockerfile`, targeting Linux AMD64 when building from an Apple Silicon Mac. Push the image to `REGION-docker.pkg.dev/PROJECT_ID/careinone/gateway:IMAGE_TAG`.
6. Edit `deploy/cloudrun.yaml` placeholders for project, region, and image tag. It specifies one vCPU, 512 MiB, concurrency 4, min instances 0, max instances 3, a 210-second request deadline, and secret references. The container listens on port 8000. No disk or patient database is attached.
7. Deploy the YAML with `gcloud run services replace deploy/cloudrun.yaml --region REGION`. Allow public invocation at Cloud Run’s transport layer so the iOS app can reach it; **the application still requires its own bearer token** for config, checks, and extraction. `/health` is intentionally public. Review your organization’s public-ingress policy first.
8. Use the assigned HTTPS `run.app` address in the app. No purchased API domain is needed. Settings → Cloud connection → check configuration → synthetic test → review recipients → allow analysis.
9. Set billing alerts, provider project spending controls, and monitoring for availability, latency, error codes, and aggregate usage. Do not log source text or provider output. Alerts are not guaranteed hard spending caps. Max instances and per-process rate limits also do not establish a global monthly spend cap.
10. Run physical-device and live-provider validation before releasing cloud analysis publicly. Test disabled consent, wrong token, changed model, timeout, quota exhaustion, offline operation, long documents, and source preservation after failures.

Google references: [container configuration](https://docs.cloud.google.com/run/docs/configuring/services/containers), [secret configuration](https://docs.cloud.google.com/run/docs/configuring/services/secrets). The YAML is prepared but has not been deployed or load-tested against your account.

## 4. Do not compromise the patient workflow to reduce cost

Already implemented: local OCR/transcription where supported; source-level exact duplicate detection; local hash/version proposal reuse; text-only provider payloads; a stable extraction prompt; bounded chunks; review before canonical commit; no model calls for screen navigation; output/source limits; cancellable analysis; and local fallback offered to the patient.

Keep outputs sufficient for all claims. Do not truncate evidence, skip pages, lower output caps blindly, or treat an empty extraction as proof that nothing matters. Do not rely on the model’s confidence alone to select a cheaper path.

Cloud caps protect availability and cost but can require splitting a long source; that limitation is disclosed. Fallback and forced re-analysis can incur additional charges. Budget them rather than claiming every capture always costs the same amount.

## 5. Monthly planning scenarios

Assumptions: 10 cloud-analyzed sources per monthly active user; each source averages 3,000 billed input and 1,000 billed output tokens across all chunks; 10% same-price retry allowance; $7 hosting allowance. No provider prompt-cache discount assumed.

| Monthly active users | Cloud sources | Mini API + hosting | Nano API + hosting, only if qualified |
|---:|---:|---:|---:|
| 100 | 1,000 | $10.08 | $7.77 |
| 1,000 | 10,000 | $37.80 | $14.70 |
| 10,000 | 100,000 | $315.00 | $84.00 |

The $7 hosting allowance is held constant **only to isolate model cost**; it is not a claim that one small service handles 100,000 uploads at the latency/concurrency you need. Actual cloud/token invoices depend on document lengths, concurrent use, reasoning, retries, and regional service pricing. Add enrollment/operations costs and required provider/hosting agreements for your deployment. Apple Developer Program membership is currently $99/year in the US, separate from API/hosting costs. [Apple membership](https://developer.apple.com/programs/whats-included/).

Run your own assumptions:

```sh
python3 scripts/estimate_cost.py --users 1000 --uploads 10
python3 scripts/estimate_cost.py --users 1000 --uploads 20 --input-tokens 8000 --output-tokens 2500 --hosting 15
python3 scripts/estimate_cost.py --custom-input-rate YOUR_VERIFIED_RATE --custom-output-rate YOUR_VERIFIED_RATE
```

`--cloud-fraction` is the fraction of captures actually sent for cloud analysis, not a proposal to withhold cloud functionality. `--cache-fraction` represents exact repeated analyses avoided locally, not cheaper provider cache-token billing.

## 6. Public launch requires one additional service boundary

**The current gateway uses operator-issued per-installation tokens. It is suitable for a controlled beta, not frictionless anonymous public enrollment.** Public patients should not enter your API key or manually maintain infrastructure.

Before an unrestricted public cloud rollout, provide automatic installation enrollment, revocation, abuse protection, and aggregate usage limits. A small non-clinical credential store can hold pseudonymous installation keys, quotas, and revocation state; it does not need patient notes, medical sources, or the care graph. Accountless device attestation or authenticated enrollment are design options. The exact enrollment service is not implemented or priced in the table above.

Never distribute one shared permanent bearer token in the app. That would let an extracted token consume your entire model budget. Keep the current local-only app fully usable while cloud enrollment is finalized. Hosting and provider retention/contract requirements must be assessed for the actual product and operator; a cheap tier is not a compliance determination.
