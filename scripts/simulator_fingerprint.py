#!/usr/bin/env python3
"""Read-only upgrade verification. Writes counts and hashes, never patient text."""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import sys


# SwiftData record tables are intentionally explicit: silently ignoring a new
# model could make an incomplete before/after comparison appear successful.
RECORD_TABLES = (
    "ZEVIDENCESOURCE", "ZENCOUNTER", "ZCAREENTITY", "ZCARECLAIM", "ZCLAIMRELATION",
    "ZCONFLICTRECORD", "ZOPENLOOP", "ZCHANGERECORD", "ZSAVEDQUESTION", "ZPATIENTNOTE",
    "ZPATIENTPROFILE", "ZAUDITEVENT",
)
# Core Data persistent-history tables observed by a schema-name-only check on
# the assigned main simulator. They are framework bookkeeping, not StoredRecord
# payload tables; their row contents are intentionally neither read nor printed.
METADATA_TABLES = frozenset({"Z_METADATA", "Z_PRIMARYKEY", "Z_MODELCACHE", "sqlite_sequence",
                             "ACHANGE", "ATRANSACTION", "ATRANSACTIONSTRING"})
APPLICATION_ROOT = Path("Library/Application Support/CareContinuity")
DEFAULT_BUNDLE_ID = "org.carecontinuity.app"


class FingerprintError(Exception):
    """Fixed diagnostic code; never include payload, row key or file name."""


def workspace_root(container: Path, workspace: str = "personal") -> Path:
    if workspace not in {"personal", "demo"}:
        raise FingerprintError("workspace_invalid")
    root = container / APPLICATION_ROOT
    if root.is_symlink():
        raise FingerprintError("workspace_symlink")
    return root if workspace == "personal" else root / "FictionalDemo"


def _reject_constant(_):
    raise FingerprintError("payload_nonfinite")


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise FingerprintError("payload_duplicate_field")
        result[key] = value
    return result


def _decode_payload(payload):
    if not isinstance(payload, (bytes, str)):
        raise FingerprintError("payload_invalid")
    try:
        value = json.loads(payload, parse_constant=_reject_constant, object_pairs_hook=_unique_object)
        if not isinstance(value, dict):
            raise FingerprintError("payload_invalid")
        return value
    except FingerprintError:
        raise
    except (ValueError, UnicodeError, RecursionError):
        raise FingerprintError("payload_invalid") from None


def fingerprint(root: Path):
    """Hash all decoded records and original evidence in exactly one workspace.

    ZPATIENTPROFILE is the complete Preferences object, including continuity,
    handoffs, visitCompanions and followThroughPlans. No selective field filter
    or raw SQLite-byte hash may omit those drafts or introduce formatting noise.
    The output shape is compatible with the original personal-only utility.
    """
    database, evidence = root / "CareContinuity.store", root / "Evidence"
    if root.is_symlink() or database.is_symlink() or evidence.is_symlink():
        raise FingerprintError("workspace_symlink")
    if not root.is_dir() or not database.is_file() or not evidence.is_dir():
        raise FingerprintError("workspace_incomplete")
    result = {"records": {}, "evidence": {}}
    connection = None
    try:
        connection = sqlite3.connect(database.absolute().as_uri() + "?mode=ro", uri=True)
        connection.execute("PRAGMA query_only = ON")
        connection.execute("BEGIN")
        actual = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        if not set(RECORD_TABLES).issubset(actual):
            raise FingerprintError("record_table_missing")
        if actual - set(RECORD_TABLES) - METADATA_TABLES:
            raise FingerprintError("record_table_unexpected")
        for table in RECORD_TABLES:
            columns = {row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')}
            if not {"ZKEY", "ZPAYLOAD"}.issubset(columns):
                raise FingerprintError("record_columns_invalid")
            rows = connection.execute(f'SELECT ZKEY, ZPAYLOAD FROM "{table}" ORDER BY ZKEY').fetchall()
            if any(not isinstance(key, str) for key, _ in rows) or len({key for key, _ in rows}) != len(rows):
                raise FingerprintError("record_key_invalid")
            canonical = [(key, _decode_payload(payload)) for key, payload in rows]
            encoded = json.dumps(canonical, sort_keys=True, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode()
            result["records"][table] = {"count": len(rows), "sha256": hashlib.sha256(encoded).hexdigest()}
    except sqlite3.Error:
        raise FingerprintError("database_unreadable") from None
    except (ValueError, UnicodeError, RecursionError):
        raise FingerprintError("payload_invalid") from None
    finally:
        if connection is not None:
            connection.close()
    try:
        for file in sorted(evidence.iterdir()):
            if file.is_symlink() or not file.is_file():
                raise FingerprintError("evidence_entry_invalid")
            digest = hashlib.sha256()
            with file.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            # Opaque filename hashes preserve rename detection without revealing
            # patient-supplied names or reading any location outside Evidence.
            result["evidence"][hashlib.sha256(file.name.encode()).hexdigest()] = digest.hexdigest()
    except OSError:
        raise FingerprintError("evidence_unreadable") from None
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--workspace", choices=("personal", "demo"), default="personal",
                        help="demo selects the isolated FictionalDemo store; default remains personal")
    parser.add_argument("--allow-absent", action="store_true",
                        help="demo only: record an absent uninitialized workspace without creating it")
    args = parser.parse_args(argv)
    try:
        process = subprocess.run(["xcrun", "simctl", "get_app_container", args.device, DEFAULT_BUNDLE_ID, "data"],
                                 check=True, capture_output=True, text=True)
        container = Path(process.stdout.strip())
        if not container.is_absolute() or not process.stdout.strip():
            raise FingerprintError("container_invalid")
        output = Path(args.output)
        if output.is_symlink() or output.resolve().is_relative_to(container.resolve()):
            raise FingerprintError("output_inside_container_or_symlink")
        root = workspace_root(container, args.workspace)
        if args.allow_absent and args.workspace != "demo":
            raise FingerprintError("absence_allowed_only_for_demo")
        if args.allow_absent and not root.exists() and not root.is_symlink():
            result = {"workspace_state": "absent", "records": {}, "evidence": {}}
        else:
            result = fingerprint(root)
        output.write_text(json.dumps(result, indent=2) + "\n")
    except FingerprintError as error:
        print(json.dumps({"status": "failed", "error_code": str(error)}), file=sys.stderr)
        return 1
    except (OSError, subprocess.SubprocessError, UnicodeError):
        # Do not echo platform exceptions that could contain private file names.
        print(json.dumps({"status": "failed", "error_code": "container_or_output_unavailable"}), file=sys.stderr)
        return 1
    print(json.dumps({"record_types": len(result["records"]), "evidence_files": len(result["evidence"]), "output": args.output}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
