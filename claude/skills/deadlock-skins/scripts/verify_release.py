#!/usr/bin/env python3
"""Read-only identity/CRC guard for single-file VPK1/2 and a release ZIP.

No extraction, installation, resource decoding, signature validation or network IO.
Python standard library only. Nonzero exit on any unsupported or mismatched input.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zipfile
import zlib


class VerificationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def sha_arg(value):
    if not re.fullmatch(r"[0-9a-fA-F]{64}", value):
        raise argparse.ArgumentTypeError("Expected a full SHA-256 hexadecimal value")
    return value.lower()


def digest_stream(stream):
    sha = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        sha.update(block)
    return sha.hexdigest()


def safe_name(name):
    require(bool(name) and not name.startswith("/"), f"Invalid archive path: {name!r}")
    require(not any(c in name for c in ("\\", ":", "\0")), f"Unsafe archive path: {name!r}")
    require(all(p not in ("", ".", "..") for p in name.split("/")), f"Noncanonical path: {name!r}")
    return name


def load_closure(path):
    """Read an expected VPK entry set: a JSON list of paths, or an object whose
    `project_files` (or `entries`) maps each path to an optional {"sha256": ...}."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("project_files", data.get("entries"))
    if isinstance(data, list):
        data = {name: None for name in data}
    require(isinstance(data, dict) and bool(data), "Closure must list at least one VPK path")
    expected = {}
    for name, meta in data.items():
        safe_name(name)
        sha = meta.get("sha256") if isinstance(meta, dict) else None
        if sha is not None:
            require(isinstance(sha, str) and re.fullmatch(r"[0-9a-fA-F]{64}", sha),
                    f"Invalid closure SHA-256 for {name}")
            sha = sha.lower()
        expected[name] = sha
    return expected


def check_closure(entry_shas, expected):
    actual = set(entry_shas)
    require(not actual - set(expected), f"VPK entries outside closure: {sorted(actual - set(expected))}")
    require(not set(expected) - actual, f"Closure entries missing from VPK: {sorted(set(expected) - actual)}")
    for name, sha in expected.items():
        require(sha is None or entry_shas[name] == sha, f"Closure SHA-256 mismatch: {name}")
    return {"entry_count": len(expected), "hashes_checked": sum(sha is not None for sha in expected.values())}


def inspect_vpk(path, model_path):
    path = Path(path).resolve(strict=True)
    safe_name(model_path)
    with path.open("rb") as f:
        size = path.stat().st_size
        header = f.read(12)
        require(len(header) == 12, "Truncated VPK header")
        magic, version, tree_size = struct.unpack("<III", header)
        require(magic == 0x55AA1234, "Not a Valve VPK signature")
        require(version in (1, 2), f"Unsupported VPK version {version}")
        if version == 2:
            extra = f.read(16)
            require(len(extra) == 16, "Truncated VPK2 header")
            data_size, archive_md5, other_md5, signature = struct.unpack("<IIII", extra)
            header_size = 28
            require(header_size + tree_size + data_size + archive_md5 + other_md5 + signature <= size,
                    "VPK2 sections extend beyond file")
        else:
            header_size = 12
            data_size = size - header_size - tree_size
        require(0 < tree_size <= min(size - header_size, 64 * 1024 * 1024),
                "Invalid or unsupported VPK tree size (maximum 64 MiB)")
        require(data_size >= 0, "Invalid VPK data section size")
        tree = f.read(tree_size)
        require(len(tree) == tree_size, "Truncated VPK directory")
        cursor = 0

        def take(n):
            nonlocal cursor
            require(cursor + n <= len(tree), "Truncated VPK tree entry")
            value = tree[cursor:cursor + n]
            cursor += n
            return value

        def cstring():
            nonlocal cursor
            end = tree.find(b"\0", cursor)
            require(end >= 0, "Unterminated VPK tree string")
            try:
                value = tree[cursor:end].decode("utf-8")
            except UnicodeDecodeError as exc:
                raise VerificationError("Invalid UTF-8 VPK path") from exc
            cursor = end + 1
            return value

        entries = []
        seen = set()
        while extension := cstring():
            while directory := cstring():
                while stem := cstring():
                    crc, preload_size, archive, offset, length, terminator = struct.unpack("<IHHIIH", take(18))
                    require(terminator == 0xFFFF, "Invalid VPK entry terminator")
                    name = ("" if directory == " " else directory + "/") + stem
                    if extension != " ":
                        name += "." + extension
                    safe_name(name)
                    require(name.casefold() not in seen, f"Duplicate VPK path: {name}")
                    seen.add(name.casefold())
                    preload = take(preload_size)
                    require(archive == 0x7FFF or length == 0,
                            f"Split VPK unsupported: {name} requires archive {archive}")
                    require(length == 0 or offset + length <= data_size, f"VPK payload outside data section: {name}")
                    entries.append((name, crc, offset, length, preload))
        require(not any(tree[cursor:]), "Unexpected nonzero VPK tree suffix")
        require(bool(entries), "Empty VPK")
        require(model_path in {e[0] for e in entries}, f"Exact runtime model path missing: {model_path}")
        entry_shas = {}
        counts = {}
        for name, expected_crc, offset, length, preload in entries:
            sha = hashlib.sha256(preload)
            actual_crc = zlib.crc32(preload)
            if length:
                f.seek(header_size + tree_size + offset)
                remaining = length
                while remaining:
                    block = f.read(min(remaining, 1024 * 1024))
                    require(bool(block), f"Truncated VPK payload: {name}")
                    remaining -= len(block)
                    sha.update(block)
                    actual_crc = zlib.crc32(block, actual_crc)
            require(actual_crc & 0xFFFFFFFF == expected_crc, f"CRC mismatch: {name}")
            suffix = Path(name).suffix.lower()
            counts[suffix] = counts.get(suffix, 0) + 1
            entry_shas[name] = sha.hexdigest()
        f.seek(0)
        artifact_sha = digest_stream(f)
    return {
        "path": str(path), "size": size, "sha256": artifact_sha, "version": version,
        "entry_count": len(entries), "extension_counts": dict(sorted(counts.items())),
        "all_entry_crcs_valid": True, "model_path": model_path, "model_sha256": entry_shas[model_path],
        "entry_sha256": entry_shas,
        "shared_animation_resources": [e[0] for e in entries if Path(e[0]).suffix.lower()
                                       in (".vnmskel_c", ".vnmgraph_c", ".vnmclip_c")],
    }


def inspect_zip(path, member, allowed, expected_vpk_sha):
    path = Path(path).resolve(strict=True)
    for name in [member, *allowed]:
        safe_name(name)
    expected = {member, *allowed}
    with path.open("rb") as raw:
        archive_sha = digest_stream(raw)
        raw.seek(0)
        with zipfile.ZipFile(raw) as archive:
            infos = archive.infolist()
            seen = set()
            files = {}
            for info in infos:
                name = info.filename[:-1] if info.is_dir() else info.filename
                safe_name(name)
                require(name.casefold() not in seen, f"Duplicate ZIP path: {name}")
                seen.add(name.casefold())
                require(not info.flag_bits & 1, f"Encrypted ZIP member unsupported: {name}")
                require((info.external_attr >> 16) & 0o170000 != 0o120000, f"ZIP symlink is not a release file: {name}")
                if info.is_dir():
                    require(any(p.startswith(name + "/") for p in expected), f"Unexpected ZIP directory: {name}")
                else:
                    require(name in expected, f"Unexpected ZIP file: {name}")
                    files[name] = info
            require(set(files) == expected, f"Missing ZIP files: {sorted(expected - set(files))}")
            file_results = []
            for name in sorted(files):
                with archive.open(files[name]) as stream:
                    sha = digest_stream(stream)  # ZipExtFile also checks CRC at EOF.
                if name == member:
                    require(sha == expected_vpk_sha, "ZIP contains a different VPK than the verified candidate")
                file_results.append({"path": name, "size": files[name].file_size, "sha256": sha})
    return {"path": str(path), "size": path.stat().st_size, "sha256": archive_sha,
            "all_entry_crcs_valid": True, "files": file_results}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vpk", required=True, type=Path)
    parser.add_argument("--expect-vpk-sha256", required=True, type=sha_arg)
    parser.add_argument("--model-path", required=True)
    parser.add_argument("--expect-model-sha256", required=True, type=sha_arg)
    parser.add_argument("--expect-closure", type=Path,
                        help="JSON closure; VPK must contain exactly these paths (and listed hashes)")
    parser.add_argument("--zip", type=Path)
    parser.add_argument("--zip-member")
    parser.add_argument("--allow-zip-file", action="append", default=[])
    args = parser.parse_args(argv)
    if bool(args.zip) != bool(args.zip_member) or (args.allow_zip_file and not args.zip):
        parser.error("--zip and --zip-member must be supplied together; ZIP allowlist needs --zip")
    try:
        result = inspect_vpk(args.vpk, args.model_path)
        require(result["sha256"] == args.expect_vpk_sha256, "Candidate VPK SHA-256 differs from selected artifact")
        require(result["model_sha256"] == args.expect_model_sha256, "Packaged model SHA-256 differs from selected compiled model")
        entry_shas = result.pop("entry_sha256")
        if args.expect_closure:
            result["closure"] = check_closure(entry_shas, load_closure(args.expect_closure))
        output = {"ok": True, "vpk": result,
                  "scope": "Artifact identity and per-entry CRC only; no model, license or runtime acceptance inference"}
        if args.zip:
            output["zip"] = inspect_zip(args.zip, args.zip_member, args.allow_zip_file, result["sha256"])
        print(json.dumps(output, indent=2))
        return 0
    except (VerificationError, OSError, ValueError, zipfile.BadZipFile, NotImplementedError, RuntimeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
