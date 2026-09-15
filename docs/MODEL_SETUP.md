# Optional model setup

The iPhone remains useful without a model account. To add cloud extraction, run the included gateway on a computer or server you control. Never paste provider secrets into a chat, a screenshot, the iPhone app, or committed files.

## Configure without putting secrets in shell history

From the repository root, after installing `backend/requirements.lock`:

```sh
.venv/bin/python -m backend.configure
.venv/bin/python -m backend.run
```

The setup command asks for provider, model ID, and a hidden API key. It creates `.env` with owner-only permissions, generates a separate gateway access token, and refuses to overwrite an existing file. It makes no network request. The runner reads this file without executing shell syntax. Existing environment variables take precedence, so production secret-manager settings remain authoritative.

The local runner binds to `127.0.0.1:8000`. Configure HTTPS in your hosting platform or reverse proxy before connecting an iPhone. The app intentionally rejects HTTP and redirects. Configure `--host` only for the interface your deployment needs. Do not expose the development mock publicly as a working model service.

## Provider choices

| Adapter | Default base URL | Request behavior |
|---|---|---|
| `openai` | `https://api.openai.com/v1` | Chat Completions JSON mode, `max_completion_tokens`, `store: false`, sampling omitted |
| `kimi` | `https://api.moonshot.ai/v1` | Chat Completions JSON mode, `max_tokens`, thinking disabled by default, sampling omitted |
| `compatible` | Explicit operator setting | Chat Completions JSON mode, `max_tokens`; optional supported sampling/thinking settings |
| `mock` | Local adapter | Explicitly labeled development proposals with unknown subject and zero confidence |

Enter a model ID that your account actually offers. Model availability and prices vary; this repository does not promise that a particular model is cheapest or universally accessible. `kimi-k2.6` is a documented compatible example, not an accuracy certification or pinned default. Measure extraction quality on synthetic examples before using a model with patient sources.

Kimi K2.6 fixes its temperature by thinking mode, so forcing zero causes request errors. The Kimi adapter omits temperature and disables thinking to keep extraction requests simpler. OpenAI uses its current completion-token parameter and explicitly declines completion storage; this flag alone does not establish a provider’s full retention policy. References checked September 15, 2026: [Kimi request parameters](https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart#parameters-differences-in-request-body), [official OpenAI documentation: Chat Completions](https://developers.openai.com/api/reference/cli/resources/chat/subresources/completions/methods/create).

## Bound cost and configure fallback

The default source limit is 40,000 characters, chunked at 10,000 with 500-character overlap. Each chunk has a maximum of 6,000 output tokens. These are ceilings, not estimated bills. A failed primary may also incur usage before fallback. Set spending limits with the provider and global request limits at your reverse proxy; per-process gateway limits are not a monthly budget.

Use `CARE_MODEL_MAX_OUTPUT_TOKENS` (256–16,000) and `CARE_MAX_SOURCE_CHARACTERS` (1,000–200,000) to adjust ceilings. `CARE_MODEL_TEMPERATURE`, `CARE_MODEL_THINKING`, and `CARE_MODEL_REASONING_EFFORT` are optional and model-specific. Unsupported values can cause provider failure.

Fallback has independent `CARE_FALLBACK_PROVIDER`, `CARE_FALLBACK_BASE_URL`, `CARE_FALLBACK_API_KEY`, `CARE_FALLBACK_MODEL`, `CARE_FALLBACK_MAX_OUTPUT_TOKENS`, and optional sampling fields. Partial configuration fails at startup. Both recipients are disclosed before patient-content consent.

## Connect the iPhone

1. Open Settings → Set up or test cloud connection.
2. Enter your gateway’s HTTPS address and its generated `CARE_BACKEND_TOKENS` value. This is a different secret from the provider API key.
3. Check gateway configuration. This authenticates and retrieves provider names, hosts, model IDs, and limits without sending patient content or calling a model.
4. Optionally run **Test with synthetic text**. It sends one fixed invented follow-up sentence and reports whether primary or fallback returned a validated proposal. This consumes a small amount of provider quota; it does not verify clinical quality.
5. Review recipients and retention, then choose **Allow cloud analysis with these models**. Saving only the connection leaves consent off.

Consent is bound to a hash of the disclosed configuration. `POST /v1/extract` requires that configuration ID; changed recipients/models return HTTP 409 before any provider call. Upgrade app and gateway together. Older clients without this field must renew consent through the updated connection screen.

The server offers authenticated `GET /v1/config` and `POST /v1/check`; the latter accepts only `{"schemaVersion":"care-schema-1.0"}` and cannot accept arbitrary patient text. `/health` is public and content-free. None of these endpoints returns API keys or evidence.

## Before real patient content

Run the synthetic connection check and review test outputs. Verify the actual hosting/provider retention terms and applicable agreements. Configure a unique random access token per installation and a revocation process. Real provider validation is not yet recorded in this repository because no provider credentials have been supplied.
