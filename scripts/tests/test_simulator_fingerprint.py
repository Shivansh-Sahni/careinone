"""Temporary fictional SQLite/evidence fixtures; no simulator or credential access."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("simulator_fingerprint", Path(__file__).parents[1] / "simulator_fingerprint.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FingerprintTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.container = Path(self.temporary.name) / "container"
        self.container.mkdir()
        self.root = MODULE.workspace_root(self.container)
        self.create_store(self.root)

    def create_store(self, root):
        (root / "Evidence").mkdir(parents=True)
        with sqlite3.connect(root / "CareContinuity.store") as connection:
            for table in MODULE.RECORD_TABLES:
                connection.execute(f'CREATE TABLE "{table}" (ZKEY TEXT, ZPAYLOAD BLOB)')
            for table in MODULE.METADATA_TABLES - {"sqlite_sequence"}:
                connection.execute(f'CREATE TABLE "{table}" (VALUE BLOB)')

    def insert(self, table, value, *, key="fictional", root=None):
        with sqlite3.connect((root or self.root) / "CareContinuity.store") as connection:
            connection.execute(f'INSERT INTO "{table}" VALUES (?, ?)', (key, json.dumps(value).encode()))

    def test_default_shape_preserves_original_decoded_payload_hashes(self):
        value = {"message": "fictional patient text", "a": {"b": [2, 1]}}
        self.insert("ZEVIDENCESOURCE", value)
        result = MODULE.fingerprint(self.root)
        original = json.dumps([("fictional", value)], sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()
        self.assertEqual(set(result), {"records", "evidence"})
        self.assertEqual(len(result["records"]), 12)
        self.assertEqual(result["records"]["ZEVIDENCESOURCE"], {"count": 1, "sha256": hashlib.sha256(original).hexdigest()})
        self.assertNotIn(value["message"], json.dumps(result))

    def test_complete_preferences_changes_include_handoffs_companions_and_plan_drafts(self):
        preferences = {"schemaVersion": 1, "profile": {}, "loopOverrides": {}, "continuity": None,
                       "handoffs": {"handoffs": [{"replyDraft": "fictional initial reply"}]},
                       "visitCompanions": {"sessions": [{"answer": "fictional first answer"}]},
                       "followThroughPlans": {"plans": [{"draft": "fictional first plan"}]}}
        self.insert("ZPATIENTPROFILE", preferences)
        baseline = MODULE.fingerprint(self.root)["records"]["ZPATIENTPROFILE"]["sha256"]
        for field in ("handoffs", "visitCompanions", "followThroughPlans", "continuity"):
            changed = dict(preferences); changed[field] = {"fictional changed draft": True}
            with sqlite3.connect(self.root / "CareContinuity.store") as connection:
                connection.execute("UPDATE ZPATIENTPROFILE SET ZPAYLOAD = ?", (json.dumps(changed).encode(),))
            self.assertNotEqual(MODULE.fingerprint(self.root)["records"]["ZPATIENTPROFILE"]["sha256"], baseline)

    def test_json_formatting_does_not_mask_semantic_upgrade_preservation(self):
        self.insert("ZPATIENTPROFILE", {"profile": {}, "schemaVersion": 1})
        baseline = MODULE.fingerprint(self.root)
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("UPDATE ZPATIENTPROFILE SET ZPAYLOAD = ?", (b'{ "schemaVersion": 1, "profile" : {} }',))
        self.assertEqual(MODULE.fingerprint(self.root), baseline)

    def test_personal_and_demo_stores_are_isolated_with_binary_original_hashes(self):
        demo = MODULE.workspace_root(self.container, "demo"); self.create_store(demo)
        self.insert("ZEVIDENCESOURCE", {"kind": "fictional personal"})
        self.insert("ZEVIDENCESOURCE", {"kind": "fictional demo"}, root=demo)
        filename = "fictional private filename.pdf"
        (self.root / "Evidence" / filename).write_bytes(b"\x00\xfffictional binary original")
        original = MODULE.fingerprint(self.root)
        self.assertNotEqual(original["records"], MODULE.fingerprint(demo)["records"])
        self.assertEqual(len(original["evidence"]), 1)
        self.assertNotIn(filename, json.dumps(original))
        (self.root / "Evidence" / filename).write_bytes(b"\x00\xfedifferent fictional binary")
        self.assertNotEqual(original["evidence"], MODULE.fingerprint(self.root)["evidence"])
        self.assertEqual(MODULE.workspace_root(self.container), MODULE.workspace_root(self.container, "personal"))

    def test_missing_and_unexpected_tables_fail_instead_of_partial_success(self):
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("CREATE TABLE ZUNREVIEWEDMODEL (ZPAYLOAD BLOB)")
        with self.assertRaisesRegex(MODULE.FingerprintError, "^record_table_unexpected$"):
            MODULE.fingerprint(self.root)
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("DROP TABLE ZUNREVIEWEDMODEL"); connection.execute("DROP TABLE ZCARECLAIM")
        with self.assertRaisesRegex(MODULE.FingerprintError, "^record_table_missing$"):
            MODULE.fingerprint(self.root)

    def test_duplicate_keys_and_malformed_payloads_fail_without_content(self):
        self.insert("ZPATIENTPROFILE", {}, key="fictional duplicate")
        self.insert("ZPATIENTPROFILE", {}, key="fictional duplicate")
        with self.assertRaisesRegex(MODULE.FingerprintError, "^record_key_invalid$"):
            MODULE.fingerprint(self.root)
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("DELETE FROM ZPATIENTPROFILE")
            connection.execute("INSERT INTO ZPATIENTPROFILE VALUES (?, ?)", ("fictional", b"fictional sensitive malformed body"))
        with self.assertRaisesRegex(MODULE.FingerprintError, "^payload_invalid$"):
            MODULE.fingerprint(self.root)

    def test_symlinks_cannot_read_evidence_outside_workspace(self):
        outside = self.container / "fictional outside content"; outside.write_bytes(b"fictional")
        (self.root / "Evidence" / "fictional link").symlink_to(outside)
        with self.assertRaisesRegex(MODULE.FingerprintError, "^evidence_entry_invalid$"):
            MODULE.fingerprint(self.root)

    def test_read_only_fingerprint_does_not_change_database_bytes(self):
        self.insert("ZPATIENTPROFILE", {"profile": {"name": "fictional"}})
        path = self.root / "CareContinuity.store"; before = path.read_bytes()
        MODULE.fingerprint(self.root)
        self.assertEqual(path.read_bytes(), before)

    def test_invalid_columns_and_ambiguous_json_are_rejected(self):
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("ALTER TABLE ZCARECLAIM RENAME COLUMN ZPAYLOAD TO ZMISSING")
        with self.assertRaisesRegex(MODULE.FingerprintError, "^record_columns_invalid$"):
            MODULE.fingerprint(self.root)
        for payload, code in ((b'{"a":1,"a":2}', "payload_duplicate_field"), (b'{"a":NaN}', "payload_nonfinite")):
            with self.assertRaisesRegex(MODULE.FingerprintError, "^" + code + "$"):
                MODULE._decode_payload(payload)
        with sqlite3.connect(self.root / "CareContinuity.store") as connection:
            connection.execute("ALTER TABLE ZCARECLAIM RENAME COLUMN ZMISSING TO ZPAYLOAD")
            connection.execute("INSERT INTO ZPATIENTPROFILE VALUES (?, ?)", ("fictional", b'{"a":1e999}'))
        with self.assertRaisesRegex(MODULE.FingerprintError, "^payload_invalid$"):
            MODULE.fingerprint(self.root)

    def test_cli_demo_option_reads_only_isolated_workspace(self):
        demo = MODULE.workspace_root(self.container, "demo"); self.create_store(demo)
        self.insert("ZPATIENTPROFILE", {"profile": {"name": "fictional demo"}}, root=demo)
        output = Path(self.temporary.name) / "safe-demo-report.json"
        process = subprocess.CompletedProcess([], 0, str(self.container) + "\n", "")
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output), "--workspace", "demo"]), 0)
        self.assertEqual(json.loads(output.read_text())["records"]["ZPATIENTPROFILE"]["count"], 1)
        self.assertEqual(MODULE.fingerprint(self.root)["records"]["ZPATIENTPROFILE"]["count"], 0)

    def test_cli_preserves_default_summary_and_sanitizes_platform_failure(self):
        output = Path(self.temporary.name) / "safe-report.json"
        process = subprocess.CompletedProcess([], 0, str(self.container) + "\n", "")
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stdout(stdout):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output)]), 0)
        self.assertEqual(json.loads(stdout.getvalue()), {"record_types": 12, "evidence_files": 0, "output": str(output)})
        with patch.object(MODULE.subprocess, "run", side_effect=OSError("fictional private file name")), contextlib.redirect_stderr(stderr):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output)]), 1)
        self.assertNotIn("private file", stderr.getvalue())
        self.assertEqual(json.loads(stderr.getvalue())["error_code"], "container_or_output_unavailable")

    def test_output_cannot_overwrite_an_original_or_database(self):
        output = self.root / "CareContinuity.store"; original = output.read_bytes()
        process = subprocess.CompletedProcess([], 0, str(self.container) + "\n", "")
        stderr = io.StringIO()
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stderr(stderr):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output)]), 1)
        self.assertEqual(output.read_bytes(), original)
        self.assertEqual(json.loads(stderr.getvalue())["error_code"], "output_inside_container_or_symlink")

    def test_absent_demo_is_explicit_and_is_never_created_or_applied_to_personal(self):
        output = Path(self.temporary.name) / "safe-absent-demo.json"
        process = subprocess.CompletedProcess([], 0, str(self.container) + "\n", "")
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output), "--workspace", "demo", "--allow-absent"]), 0)
        self.assertEqual(json.loads(output.read_text()), {"workspace_state": "absent", "records": {}, "evidence": {}})
        self.assertFalse(MODULE.workspace_root(self.container, "demo").exists())
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output), "--allow-absent"]), 1)

    def test_absence_flag_does_not_hide_partially_present_demo(self):
        demo = MODULE.workspace_root(self.container, "demo"); demo.mkdir()
        output = Path(self.temporary.name) / "safe-partial-demo.json"
        process = subprocess.CompletedProcess([], 0, str(self.container) + "\n", "")
        stderr = io.StringIO()
        with patch.object(MODULE.subprocess, "run", return_value=process), contextlib.redirect_stderr(stderr):
            self.assertEqual(MODULE.main(["--device", "fictional-udid", "--output", str(output), "--workspace", "demo", "--allow-absent"]), 1)
        self.assertEqual(json.loads(stderr.getvalue())["error_code"], "workspace_incomplete")


if __name__ == "__main__":
    unittest.main()
