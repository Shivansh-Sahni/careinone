"""Verify a deployed gateway without printing credentials or patient evidence.

    python -m backend.verify_gateway --token-stdin

Read one gateway token from stdin, or set CARE_GATEWAY_TOKEN privately. Inside
the deployed server only, --server-environment explicitly opts into reading
the first configured CARE_BACKEND_TOKENS value without printing/exporting it.
The default operation reads health/config only and does not use paid model quota.
--synthetic opts into one fixed synthetic check; --extract opts into one fixed
fictional source extraction. At most two model-facing gateway requests can be
made per run; a configured fallback can increase provider attempts.
Only a bounded, non-PHI JSON summary is printed or written to --output.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

from .providers import CompatibleProvider, NoRedirect, PROVIDER_ERROR_MESSAGES, looks_like_credential, validate_model_identifier
from .schema import VERSION, VALIDATION_CODES, loads, validate_envelope


FICTIONAL_SOURCE = "Fictional verification patient Alex Example. My clinician ordered a CBC blood test today. My mother has diabetes. The clinician said to consider MRI if pain persists; no MRI was ordered."


def safe_provider(value, private_tokens=()):
    if not isinstance(value, dict) or set(value) != {"adapter", "model", "host", "maxOutputTokens"}: raise ValueError()
    adapter, model, host, output = (value[key] for key in ("adapter", "model", "host", "maxOutputTokens"))
    if any(token in field for token in private_tokens if token for field in (model, host) if isinstance(field, str)): raise ValueError()
    if adapter == "mock":
        if (model, host, output) != ("synthetic-development", "local development", 0): raise ValueError()
    else:
        if adapter not in {"openai", "kimi", "compatible", "custom"}: raise ValueError()
        validate_model_identifier(model, "")
        if adapter == "custom":
            if (model, host, output) != ("configured", "custom adapter", 0): raise ValueError()
        else:
            if not isinstance(host, str): raise ValueError()
            CompatibleProvider("https://" + host + "/v1", "verification-placeholder", model, adapter=adapter, max_output_tokens=output)
    return {"adapter": adapter, "model": model, "host": host, "maxOutputTokens": output}


def safe_providers(value, private_tokens=()):
    if not isinstance(value, dict) or set(value) != {"primary", "fallback"}: raise ValueError()
    return {"primary": safe_provider(value["primary"], private_tokens), "fallback": safe_provider(value["fallback"], private_tokens) if value["fallback"] is not None else None}


def fetch(base, path, token=None, payload=None, limit=32_000):
    headers = {"Accept": "application/json"}
    if token: headers["Authorization"] = "Bearer " + token
    if payload is not None: headers["Content-Type"] = "application/json"
    request = urllib.request.Request(base + path, data=json.dumps(payload).encode() if payload is not None else None, headers=headers)
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=60) as response:
            raw = response.read(limit + 1)
            if len(raw) > limit: return {"passed": False, "error": "oversized_response"}, None
            if response.headers.get("Cache-Control") != "no-store": return {"passed": False, "error": "missing_no_store"}, None
            value = loads(raw)
            return {"passed": True, "httpStatus": response.status}, value
    except urllib.error.HTTPError as exc:
        summary = {"passed": False, "httpStatus": exc.code}
        try:
            raw = exc.read(32_001)
            if len(raw) <= 32_000:
                value = loads(raw)
                code = value.get("errorCode") if isinstance(value, dict) else None
                if code in PROVIDER_ERROR_MESSAGES: summary["errorCode"] = code
                validation = value.get("validationCode") if isinstance(value, dict) else None
                if validation in VALIDATION_CODES: summary["validationCode"] = validation
        except Exception: pass
        exc.close()
        return summary, None
    except Exception:
        return {"passed": False, "error": "network_or_invalid_response"}, None


def verify(base, token, *, synthetic=False, extract=False):
    CompatibleProvider(base, "verification-placeholder", "verification-model")
    if base.rstrip('/').count('/') != 2: raise ValueError("Use the gateway HTTPS origin without an endpoint path")
    if token and (not 32 <= len(token) <= 4000 or any(ord(c) <= 32 or ord(c) >= 127 for c in token) or looks_like_credential(token)):
        raise ValueError("Use a gateway token, not a provider API key")
    if token and token in base: raise ValueError("A gateway token cannot be used in a gateway URL")
    base = base.rstrip('/')
    report = {"checkedAtUTC": dt.datetime.now(dt.timezone.utc).isoformat(), "paidRequestsAttempted": 0, "syntheticOnly": True}
    status, health = fetch(base, "/health")
    if status["passed"] and health != {"status": "ok", "schemaVersion": VERSION}: status = {"passed": False, "error": "unsupported_health"}
    report["health"] = status
    if not token:
        report["configuration"] = {"passed": False, "error": "gateway_token_unavailable"}
        report["liveInferenceVerified"] = False
        return report
    status, config = fetch(base, "/v1/config", token)
    try:
        if status["passed"]:
            if not isinstance(config, dict) or config.get("schemaVersion") != VERSION: raise ValueError()
            identifier = config.get("configurationID")
            if not isinstance(identifier, str) or len(identifier) != 64 or any(c not in '0123456789abcdef' for c in identifier): raise ValueError()
            if type(config.get("maxSourceCharacters")) is not int or not 1000 <= config["maxSourceCharacters"] <= 200000: raise ValueError()
            if type(config.get("patientContentStored")) is not bool: raise ValueError()
            status.update(providers=safe_providers(config.get("providers"), (token,)), patientContentStored=config["patientContentStored"], maxSourceCharacters=config["maxSourceCharacters"])
    except Exception:
        status = {"passed": False, "error": "unsafe_or_invalid_configuration"}
    report["configuration"] = status
    report["liveInferenceVerified"] = False
    if not status["passed"]: return report
    if synthetic:
        report["paidRequestsAttempted"] += 1
        checked, result = fetch(base, "/v1/check", token, {"schemaVersion": VERSION})
        try:
            if checked["passed"]:
                if not isinstance(result, dict) or result.get("schemaVersion") != VERSION or result.get("status") != "ok" or result.get("syntheticOnly") is not True or result.get("route") not in {"primary", "fallback"}: raise ValueError()
                providers = safe_providers(result.get("providers"), (token,))
                if providers != status["providers"]: raise ValueError()
                checked["route"] = result["route"]
                report["liveInferenceVerified"] = providers[result["route"]]["adapter"] not in {"mock", "custom"}
        except Exception:
            checked = {"passed": False, "error": "unsafe_or_invalid_check_result"}
        report["connectionCheck"] = checked
    if extract:
        report["paidRequestsAttempted"] += 1
        checked, result = fetch(base, "/v1/extract", token, {"schemaVersion": VERSION, "text": FICTIONAL_SOURCE, "sourceKind": "typed", "consent": True, "providerConfigurationID": config["configurationID"]}, limit=1_000_000)
        try:
            if checked["passed"]:
                envelope = validate_envelope(result, FICTIONAL_SOURCE)
                checked.update(claimCount=len(envelope["claims"]), exactQuotesValidated=True)
        except Exception:
            checked = {"passed": False, "error": "extraction_schema_or_quotes_invalid"}
        report["fictionalExtraction"] = checked
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="https://careinone-api.onrender.com")
    credentials = parser.add_mutually_exclusive_group()
    credentials.add_argument("--token-stdin", action="store_true", help="Read the gateway token from stdin; never put it in command arguments")
    credentials.add_argument("--server-environment", action="store_true", help="Inside the deployed server only, use its first CARE_BACKEND_TOKENS entry without printing or exporting it")
    parser.add_argument("--synthetic", action="store_true", help="Make one small, paid synthetic connection check")
    parser.add_argument("--extract", action="store_true", help="Make one small, paid fictional source extraction")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.server_environment:
        token = next((value.strip() for value in os.getenv("CARE_BACKEND_TOKENS", "").split(',') if value.strip()), "")
    else:
        token = sys.stdin.read().strip() if args.token_stdin else os.getenv("CARE_GATEWAY_TOKEN", "")
    try: report = verify(args.url, token, synthetic=args.synthetic, extract=args.extract)
    except Exception: report = {"passed": False, "error": "invalid_verification_configuration", "paidRequestsAttempted": 0}
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output: args.output.write_text(rendered)
    print(rendered, end="")
    checks = [value for value in report.values() if isinstance(value, dict) and "passed" in value]
    if not checks or not all(value["passed"] for value in checks): raise SystemExit(1)


if __name__ == "__main__": main()
