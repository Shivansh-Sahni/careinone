"""Small strict wire schema. No clinical winner selection or canonical state here."""
from __future__ import annotations
import datetime as dt
import json
import math

VERSION = "care-schema-1.0"
KINDS = set("medication condition allergy labTest resultType referral appointment procedure provider instruction followUp administrativeTask other".split())
ACTIONS = set("mentioned taking started stopped changed ordered requested scheduled completed resultAvailable followUpKnown referralPlaced appointmentScheduled visitCompleted planned prepNeeded inProgress dismissed".split())
CERTAINTIES = set("unknown notProvided reported documented uncertain conditional disputed historical superseded completedByUserReport".split())
SUBJECTS = {"patient", "family", "other", "unknown"}
PRECISIONS = {"exact", "approximate", "unknown"}
FIELDS = {
    "kind", "label", "quote", "action", "value", "numericValue", "unit", "route", "frequency", "form", "eventDate", "effectiveDate", "dueDate",
    "duePrecision", "intervalDays", "page", "transcriptSeconds", "subject", "speaker", "speakerUncertain", "certainty", "negated", "conditional", "confidence", "clarification", "code", "codeSystem"
}
class ValidationError(ValueError): pass

def loads(raw: bytes | str):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValidationError("Duplicate JSON keys are not permitted")
            result[key] = value
        return result
    def invalid_constant(value): raise ValidationError("Non-finite JSON number")
    try: return json.loads(raw, object_pairs_hook=unique, parse_constant=invalid_constant)
    except (ValueError, UnicodeError) as exc: raise ValidationError("Invalid JSON") from exc

def date(value):
    if value is None: return
    if not isinstance(value, str) or len(value) > 40: raise ValidationError("Invalid date")
    try:
        if len(value) == 10: dt.date.fromisoformat(value)
        else: dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc: raise ValidationError("Invalid ISO date") from exc

def validate_request(value):
    if not isinstance(value, dict) or set(value) - {"schemaVersion", "text", "sourceKind", "eventDate", "consent"}: raise ValidationError("Unknown request fields")
    if value.get("schemaVersion") != VERSION: raise ValidationError("Unsupported schema version")
    if value.get("consent") is not True: raise ValidationError("Explicit cloud consent required")
    text = value.get("text")
    if not isinstance(text, str) or not text.strip() or len(text) > 200_000: raise ValidationError("Text must contain 1–200,000 characters")
    if value.get("sourceKind") not in {"voice", "visitRecording", "typed", "photo", "pdf", "textFile", "fhir", "manual"}: raise ValidationError("Unsupported source kind")
    date(value.get("eventDate")); return value

def validate_claim(claim, text):
    if not isinstance(claim, dict) or set(claim) - FIELDS: raise ValidationError("Unknown proposal fields")
    if claim.get("kind") not in KINDS: raise ValidationError("Unsupported entity kind")
    for key, limit in [("label",200),("quote",6000)]:
        if not isinstance(claim.get(key), str) or not claim[key].strip() or len(claim[key]) > limit: raise ValidationError("Missing or oversized required field")
    if claim["quote"] not in text: raise ValidationError("Supporting quote not found exactly")
    for key, limit in [("value",4000),("unit",80),("route",200),("frequency",200),("form",200),("speaker",200),("clarification",500),("code",200),("codeSystem",500)]:
        if claim.get(key) is not None and (not isinstance(claim[key], str) or len(claim[key]) > limit): raise ValidationError("Invalid text field")
    for key, allowed in [("action",ACTIONS),("certainty",CERTAINTIES),("subject",SUBJECTS),("duePrecision",PRECISIONS)]:
        if claim.get(key) is not None and claim[key] not in allowed: raise ValidationError("Invalid enumeration")
    for key in ["negated", "conditional", "speakerUncertain"]:
        if claim.get(key) is not None and type(claim[key]) is not bool: raise ValidationError("Expected boolean")
    for key in ["numericValue", "confidence", "transcriptSeconds"]:
        v = claim.get(key)
        if v is not None and (type(v) not in (int,float) or not math.isfinite(v)): raise ValidationError("Expected finite numeric value")
    if claim.get("confidence") is not None and not 0 <= claim["confidence"] <= 1: raise ValidationError("Confidence outside range")
    if claim.get("transcriptSeconds") is not None and claim["transcriptSeconds"] < 0: raise ValidationError("Invalid timestamp")
    for key, low, high in [("page",1,200),("intervalDays",0,36500)]:
        v = claim.get(key)
        if v is not None and (type(v) is not int or not low <= v <= high): raise ValidationError("Invalid integer field")
    for key in ["eventDate", "effectiveDate", "dueDate"]: date(claim.get(key))
    if claim.get("duePrecision") in {"exact","approximate"} and not claim.get("dueDate") and claim.get("intervalDays") is None: raise ValidationError("Due precision requires a date")
    # Absence of attribution/confidence always becomes explicit uncertainty.
    clean = {**claim}; clean.setdefault("subject", "unknown"); clean.setdefault("confidence", 0); clean.setdefault("certainty", "uncertain"); clean.setdefault("speakerUncertain", True)
    return clean

def validate_envelope(value, text):
    if not isinstance(value, dict) or set(value) != {"schemaVersion", "claims"} or value["schemaVersion"] != VERSION: raise ValidationError("Unsupported envelope")
    if not isinstance(value["claims"], list) or len(value["claims"]) > 200: raise ValidationError("Too many proposals")
    result = []; seen = set()
    for raw in value["claims"]:
        claim = validate_claim(raw, text)
        key = json.dumps(claim, sort_keys=True, ensure_ascii=False)
        if key not in seen: result.append(claim); seen.add(key)
    return {"schemaVersion": VERSION, "claims": result}

def chunks(text, size=10000, overlap=500):
    if size <= 0 or overlap < 0 or overlap >= size: raise ValueError("Invalid chunk bounds")
    start = 0
    while start < len(text):
        end = min(start + size, len(text)); yield text[start:end]
        if end == len(text): break
        start = end - overlap
