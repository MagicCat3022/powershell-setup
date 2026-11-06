"""Synthetic release-identity regression tests; no game files or character assets."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile
import zlib

import verify_release as guard


MODEL = "models/heroes/test.vmdl_c"


def vpk_bytes(payload=b"new compiled model", version=1, preload_size=3, archive=0x7FFF,
              model_name="test", corrupt_crc=False):
    preload, stored = payload[:preload_size], payload[preload_size:]
    crc = zlib.crc32(payload) ^ (1 if corrupt_crc else 0)
    tree = b"vmdl_c\0models/heroes\0" + model_name.encode() + b"\0"
    tree += struct.pack("<IHHIIH", crc, len(preload), archive, 0, len(stored), 0xFFFF)
    tree += preload + b"\0\0\0"
    header = struct.pack("<III", 0x55AA1234, version, len(tree))
    if version == 2:
        header += struct.pack("<IIII", len(stored), 0, 0, 0)
    return header + tree + stored


class ReleaseGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="deadlock-release-guard-")
        self.root = Path(self.temp.name)
        self.vpk = self.root / "candidate.vpk"

    def tearDown(self):
        self.temp.cleanup()

    def write_vpk(self, **kwargs):
        data = vpk_bytes(**kwargs)
        self.vpk.write_bytes(data)
        return hashlib.sha256(data).hexdigest()

    def test_v1_and_v2_with_preload(self):
        for version in (1, 2):
            with self.subTest(version=version):
                sha = self.write_vpk(version=version)
                result = guard.inspect_vpk(self.vpk, MODEL)
                self.assertEqual(result["sha256"], sha)
                self.assertEqual(result["model_sha256"], hashlib.sha256(b"new compiled model").hexdigest())
                self.assertEqual(result["entry_count"], 1)

    def test_preload_only(self):
        self.write_vpk(preload_size=100, archive=0)
        self.assertTrue(guard.inspect_vpk(self.vpk, MODEL)["all_entry_crcs_valid"])

    def test_bad_payload_crc(self):
        self.write_vpk(corrupt_crc=True)
        with self.assertRaisesRegex(guard.VerificationError, "CRC mismatch"):
            guard.inspect_vpk(self.vpk, MODEL)

    def test_split_archive_stops(self):
        self.write_vpk(archive=1)
        with self.assertRaisesRegex(guard.VerificationError, "Split VPK unsupported"):
            guard.inspect_vpk(self.vpk, MODEL)

    def test_truncated_vpk_stops(self):
        self.write_vpk()
        self.vpk.write_bytes(self.vpk.read_bytes()[:-1])
        with self.assertRaisesRegex(guard.VerificationError, "outside data section"):
            guard.inspect_vpk(self.vpk, MODEL)

    def test_wrong_model_path_stops(self):
        self.write_vpk()
        with self.assertRaisesRegex(guard.VerificationError, "Exact runtime model path missing"):
            guard.inspect_vpk(self.vpk, "models/heroes/old.vmdl_c")

    def test_unsafe_vpk_path_stops(self):
        self.write_vpk(model_name="../test")
        with self.assertRaisesRegex(guard.VerificationError, "Noncanonical"):
            guard.inspect_vpk(self.vpk, MODEL)

    def test_wrong_outer_or_inner_hash_exit_nonzero(self):
        actual = self.write_vpk()
        model_sha = hashlib.sha256(b"new compiled model").hexdigest()
        for outer, inner in (("0" * 64, model_sha), (actual, "0" * 64)):
            with self.subTest(outer=outer), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                result = guard.main(["--vpk", str(self.vpk), "--expect-vpk-sha256", outer,
                                     "--model-path", MODEL, "--expect-model-sha256", inner])
                self.assertEqual(result, 1)

    def write_closure(self, data):
        path = self.root / "closure.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def run_main(self, *extra):
        actual = self.write_vpk()
        model_sha = hashlib.sha256(b"new compiled model").hexdigest()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return guard.main(["--vpk", str(self.vpk), "--expect-vpk-sha256", actual,
                               "--model-path", MODEL, "--expect-model-sha256", model_sha, *extra])

    def test_closure_exact_list_and_hash_succeed(self):
        model_sha = hashlib.sha256(b"new compiled model").hexdigest()
        for data in ([MODEL], {"project_files": {MODEL: {"sha256": model_sha.upper()}}}):
            with self.subTest(data=data):
                self.assertEqual(self.run_main("--expect-closure", str(self.write_closure(data))), 0)

    def test_closure_mismatch_stops(self):
        for data, message in (([MODEL, "materials/missing.vmat_c"], "missing from VPK"),
                              (["models/heroes/other.vmdl_c"], "outside closure"),
                              ({"project_files": {MODEL: {"sha256": "0" * 64}}}, "Closure SHA-256 mismatch")):
            with self.subTest(message=message):
                self.write_vpk()
                with self.assertRaisesRegex(guard.VerificationError, message):
                    result = guard.inspect_vpk(self.vpk, MODEL)
                    guard.check_closure(result["entry_sha256"], guard.load_closure(self.write_closure(data)))
                self.assertEqual(self.run_main("--expect-closure", str(self.write_closure(data))), 1)

    def make_zip(self, data=None, extra=None):
        path = self.root / "release.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("skin.vpk", self.vpk.read_bytes() if data is None else data)
            archive.writestr("README.txt", "Synthetic test")
            if extra:
                archive.writestr(*extra)
        return path

    def test_exact_zip_succeeds(self):
        sha = self.write_vpk()
        path = self.make_zip()
        result = guard.inspect_zip(path, "skin.vpk", ["README.txt"], sha)
        self.assertEqual(len(result["files"]), 2)

    def test_zip_stale_vpk_stops(self):
        sha = self.write_vpk()
        path = self.make_zip(data=vpk_bytes(payload=b"old stretched model"))
        with self.assertRaisesRegex(guard.VerificationError, "different VPK"):
            guard.inspect_zip(path, "skin.vpk", ["README.txt"], sha)

    def test_zip_unreviewed_payload_stops(self):
        sha = self.write_vpk()
        path = self.make_zip(extra=("private-note.txt", "Synthetic private note"))
        with self.assertRaisesRegex(guard.VerificationError, "Unexpected ZIP file"):
            guard.inspect_zip(path, "skin.vpk", ["README.txt"], sha)

    def test_zip_traversal_and_case_duplicate_stop(self):
        sha = self.write_vpk()
        for name, message in (("../extra.txt", "Noncanonical"), ("SKIN.VPK", "Duplicate ZIP")):
            with self.subTest(name=name):
                path = self.make_zip(extra=(name, "x"))
                with self.assertRaisesRegex(guard.VerificationError, message):
                    guard.inspect_zip(path, "skin.vpk", ["README.txt"], sha)

    def test_zip_symlink_stops(self):
        sha = self.write_vpk()
        symlink = zipfile.ZipInfo("link")
        symlink.create_system = 3
        symlink.external_attr = 0o120777 << 16
        path = self.make_zip(extra=(symlink, "README.txt"))
        with self.assertRaisesRegex(guard.VerificationError, "symlink"):
            guard.inspect_zip(path, "skin.vpk", ["README.txt", "link"], sha)


if __name__ == "__main__":
    unittest.main()
