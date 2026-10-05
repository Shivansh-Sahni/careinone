#!/usr/bin/env python3
"""Inspect native App Store PNG assets without changing or resizing them."""
import argparse
import hashlib
import json
import struct
import zlib
from datetime import datetime, timezone
from pathlib import Path


GROUPS = {
    "iphone-6.9": {(1260, 2736), (1290, 2796), (1320, 2868)},
    "ipad-13": {(2064, 2752), (2048, 2732)},
}


def inspect(path: Path, dimensions: set[tuple[int, int]]) -> dict:
    content = path.read_bytes()
    result = {"file": path.name, "bytes": len(content),
              "sha256": hashlib.sha256(content).hexdigest(), "errors": []}
    if len(content) < 33 or content[:8] != b"\x89PNG\r\n\x1a\n" or content[12:16] != b"IHDR":
        result["errors"].append("Not a valid PNG header")
        return result
    if struct.unpack(">I", content[8:12])[0] != 13:
        result["errors"].append("Invalid PNG IHDR length")
        return result
    width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", content[16:29])
    result.update(width=width, height=height, bit_depth=depth, color_type=color)
    accepted = dimensions | {(height, width) for width, height in dimensions}
    if (width, height) not in accepted:
        result["errors"].append("Dimensions do not match the selected required device group")
    if color in (4, 6):
        result["errors"].append("PNG alpha channel must be removed for App Store screenshots")
    if color not in (0, 2, 3, 4, 6) or compression != 0 or filtering != 0 or interlace not in (0, 1):
        result["errors"].append("Unsupported or invalid PNG encoding")
    # Palette transparency can exist without alpha in IHDR. Inspect chunk types.
    offset = 8
    found_end = False
    found_pixels = False
    while offset + 12 <= len(content):
        length = struct.unpack(">I", content[offset:offset + 4])[0]
        chunk = content[offset + 4:offset + 8]
        if offset + length + 12 > len(content):
            result["errors"].append("Truncated PNG chunk")
            break
        expected_crc = struct.unpack(">I", content[offset + length + 8:offset + length + 12])[0]
        if zlib.crc32(content[offset + 4:offset + length + 8]) != expected_crc:
            result["errors"].append("PNG chunk checksum mismatch")
            break
        found_pixels |= chunk == b"IDAT"
        if chunk == b"tRNS":
            result["errors"].append("PNG transparency is not accepted")
        offset += length + 12
        if chunk == b"IEND":
            found_end = length == 0
            break
    if not found_end or not found_pixels:
        result["errors"].append("PNG is incomplete")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).parent / "screenshots")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = {"checked_at": datetime.now(timezone.utc).isoformat(), "groups": {},
              "scope": "PNG format/dimensions only; visual and final-build review required"}
    complete = True
    for group, sizes in GROUPS.items():
        files = sorted((args.root / group).glob("*.png"))
        results = [inspect(path, sizes) for path in files]
        errors = [error for item in results for error in item["errors"]]
        if not 1 <= len(files) <= 10:
            errors.append("Group requires 1–10 PNG screenshots; none means pending")
        report["groups"][group] = {"status": "pass" if not errors else "pending_or_invalid",
                                   "files": results, "errors": errors}
        complete &= not errors
    report["status"] = "format_pass" if complete else "pending_or_invalid"
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    print(rendered, end="")
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
