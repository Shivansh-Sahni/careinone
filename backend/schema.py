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
VALIDATION_MESSAGE_CODES = {
    "Invalid JSON": "json_invalid", "Unsupported envelope": "envelope_invalid",
    "Too many proposals": "proposal_limit", "Unknown proposal fields": "unknown_fields",
    "Unsupported entity kind": "kind_invalid", "Missing or oversized required field": "required_field_invalid",
    "Supporting quote not found exactly": "quote_not_exact", "Invalid text field": "text_field_invalid",
    "Invalid enumeration": "enumeration_invalid", "Expected boolean": "boolean_invalid",
    "Expected finite numeric value": "numeric_invalid", "Confidence outside range": "numeric_invalid",
    "Invalid timestamp": "numeric_invalid", "Invalid integer field": "integer_invalid",
    "Invalid date": "date_invalid", "Invalid ISO date": "date_invalid",
    "Due precision requires a date": "due_precision_invalid",
}
VALIDATION_CODES = frozenset(VALIDATION_MESSAGE_CODES.values()) | {
    "validation_unknown", "provider_envelope_invalid", "output_incomplete", "output_refused",
    "output_missing", "response_oversized",
}

class ValidationError(ValueError):
    @property
    def validation_code(self):
        # Only fixed categories are disclosed, never offending keys or values.
        return VALIDATION_MESSAGE_CODES.get(str(self), "validation_unknown")

def openai_output_schema():
    """Strict Structured Outputs schema; unknown optional values remain null.

    Exact evidence matching and semantic relationships are still validated by
    validate_envelope after receipt. This schema does not verify clinical facts.
    """
    properties = {"kind": {"type": "string", "enum": sorted(KINDS)},
                  "label": {"type": "string"}, "quote": {"type": "string"}}
    for key in ("value", "unit", "route", "frequency", "form", "eventDate", "effectiveDate", "dueDate", "speaker", "clarification", "code", "codeSystem"):
        properties[key] = {"type": ["string", "null"]}
    for key, allowed in (("action", ACTIONS), ("certainty", CERTAINTIES), ("subject", SUBJECTS), ("duePrecision", PRECISIONS)):
        properties[key] = {"type": ["string", "null"], "enum": [*sorted(allowed), None]}
    for key in ("negated", "conditional", "speakerUncertain"):
        properties[key] = {"type": ["boolean", "null"]}
    for key in ("numericValue", "confidence", "transcriptSeconds"):
        properties[key] = {"type": ["number", "null"]}
    for key in ("page", "intervalDays"):
        properties[key] = {"type": ["integer", "null"]}
    assert set(properties) == FIELDS
    return {"type": "object", "additionalProperties": False, "required": ["schemaVersion", "claims"],
            "properties": {"schemaVersion": {"type": "string", "enum": [VERSION]},
                           "claims": {"type": "array", "maxItems": 30,
                                      "items": {"type": "object", "additionalProperties": False,
                                                "properties": properties, "required": list(properties)}}}}

def has_unpaired_surrogate(value):
    # Escaped lone UTF-16 surrogates are accepted by json.loads but cannot be
    # encoded as UTF-8 for provider requests or app responses.
    return any(0xD800 <= ord(character) <= 0xDFFF for character in value)

def loads(raw: bytes | str):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValidationError("Duplicate JSON keys are not permitted")
            result[key] = value
        return result
    def invalid_constant(value): raise ValidationError("Non-finite JSON number")
    try:
        if isinstance(raw, (bytes, bytearray)): raw = raw.decode('utf-8-sig')
        if not isinstance(raw, str): raise ValidationError("Invalid JSON")
        # A wire envelope needs only a few levels. Bound nesting before the JSON
        # decoder allocates deep structures; brackets inside evidence strings do
        # not count, including escaped quotes and backslashes.
        depth=0; in_string=False; escaped=False
        for character in raw:
            if in_string:
                if escaped: escaped=False
                elif character == '\\': escaped=True
                elif character == '"': in_string=False
            elif character == '"': in_string=True
            elif character in '[{':
                depth+=1
                if depth>64: raise ValidationError("JSON nesting exceeds the supported limit")
            elif character in ']}': depth-=1
        return json.loads(raw, object_pairs_hook=unique, parse_constant=invalid_constant)
    except (ValueError, UnicodeError, RecursionError) as exc: raise ValidationError("Invalid JSON") from exc

def date(value):
    if value is None: return
    if not isinstance(value, str) or len(value) > 40: raise ValidationError("Invalid date")
    try:
        if len(value) == 10: dt.date.fromisoformat(value)
        else: dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc: raise ValidationError("Invalid ISO date") from exc

def validate_request(value):
    if not isinstance(value, dict) or set(value) - {"schemaVersion", "text", "sourceKind", "eventDate", "consent", "providerConfigurationID"}: raise ValidationError("Unknown request fields")
    identifier = value.get('providerConfigurationID')
    if identifier is not None and (not isinstance(identifier, str) or len(identifier) != 64 or any(c not in '0123456789abcdef' for c in identifier)): raise ValidationError('Invalid provider consent configuration')
    if value.get("schemaVersion") != VERSION: raise ValidationError("Unsupported schema version")
    if value.get("consent") is not True: raise ValidationError("Explicit cloud consent required")
    text = value.get("text")
    if not isinstance(text, str) or not text.strip() or len(text) > 200_000 or has_unpaired_surrogate(text): raise ValidationError("Text must contain 1–200,000 valid Unicode characters")
    if not isinstance(value.get("sourceKind"), str) or value["sourceKind"] not in {"voice", "visitRecording", "typed", "photo", "pdf", "textFile", "fhir", "manual"}: raise ValidationError("Unsupported source kind")
    date(value.get("eventDate")); return value

def validate_claim(claim, text):
    if not isinstance(claim, dict) or set(claim) - FIELDS: raise ValidationError("Unknown proposal fields")
    if not isinstance(claim.get("kind"), str) or claim["kind"] not in KINDS: raise ValidationError("Unsupported entity kind")
    for key, limit in [("label",200),("quote",6000)]:
        if not isinstance(claim.get(key), str) or not claim[key].strip() or len(claim[key]) > limit or has_unpaired_surrogate(claim[key]): raise ValidationError("Missing or oversized required field")
    if claim["quote"] not in text: raise ValidationError("Supporting quote not found exactly")
    for key, limit in [("value",4000),("unit",80),("route",200),("frequency",200),("form",200),("speaker",200),("clarification",500),("code",200),("codeSystem",500)]:
        if claim.get(key) is not None and (not isinstance(claim[key], str) or len(claim[key]) > limit or has_unpaired_surrogate(claim[key])): raise ValidationError("Invalid text field")
    for key, allowed in [("action",ACTIONS),("certainty",CERTAINTIES),("subject",SUBJECTS),("duePrecision",PRECISIONS)]:
        if claim.get(key) is not None and (not isinstance(claim[key], str) or claim[key] not in allowed): raise ValidationError("Invalid enumeration")
    for key in ["negated", "conditional", "speakerUncertain"]:
        if claim.get(key) is not None and type(claim[key]) is not bool: raise ValidationError("Expected boolean")
    for key in ["numericValue", "confidence", "transcriptSeconds"]:
        v = claim.get(key)
        if v is not None:
            try: finite = type(v) in (int,float) and math.isfinite(v)
            except OverflowError: finite = False
            if not finite: raise ValidationError("Expected finite numeric value")
    if claim.get("confidence") is not None and not 0 <= claim["confidence"] <= 1: raise ValidationError("Confidence outside range")
    if claim.get("transcriptSeconds") is not None and claim["transcriptSeconds"] < 0: raise ValidationError("Invalid timestamp")
    for key, low, high in [("page",1,200),("intervalDays",0,36500)]:
        v = claim.get(key)
        if v is not None and (type(v) is not int or not low <= v <= high): raise ValidationError("Invalid integer field")
    for key in ["eventDate", "effectiveDate", "dueDate"]: date(claim.get(key))
    if claim.get("duePrecision") in {"exact","approximate"} and not claim.get("dueDate") and claim.get("intervalDays") is None: raise ValidationError("Due precision requires a date")
    # Absence of attribution/confidence always becomes explicit uncertainty.
    clean = {**claim}
    for key, default in (("subject", "unknown"), ("confidence", 0), ("certainty", "uncertain"), ("speakerUncertain", True)):
        if clean.get(key) is None: clean[key] = default
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
