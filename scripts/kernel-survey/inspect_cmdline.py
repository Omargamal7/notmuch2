#!/usr/bin/env python3
"""Dump the kernel cmdline / bootconfig from Android boot.img and vendor_boot.img.

Usage:  python3 inspect_cmdline.py <file-or-directory> [...]

Reports, per image:
  - boot.img      : header cmdline field (v3/v4) or cmdline+extra_cmdline (v0-v2)
  - vendor_boot   : vendor cmdline + bootconfig section
and flags any mitigation/speculation-related parameters found.
"""
import os
import re
import struct
import sys

FLAG_RE = re.compile(
    r"mitigat|spectre|spec_store|ssbd|nospec|kpti|nopti|kasan|nokaslr|"
    r"retbleed|l1tf|mds|tsx|srbds",
    re.I,
)


def _cstr(b):
    return b.split(b"\x00")[0].decode("utf-8", "replace")


def read_boot(d):
    """Android boot image. Returns (label, cmdline)."""
    hv = struct.unpack_from("<I", d, 40)[0]
    if hv >= 3:
        # v3/v4: cmdline is a single 1536-byte field at offset 44
        return f"boot.img (header v{hv})", _cstr(d[44 : 44 + 1536])
    # v0-v2: page_size at 36, cmdline at 64 (512B), extra_cmdline at 608 (1024B)
    cmd = _cstr(d[64 : 64 + 512])
    extra = _cstr(d[608 : 608 + 1024])
    return f"boot.img (header v{hv})", " ".join(x for x in (cmd, extra) if x)


def read_vendor_boot(d):
    """Vendor boot image. Returns (label, cmdline, bootconfig)."""
    hv, page_size = struct.unpack_from("<II", d, 8)
    vrsize = struct.unpack_from("<I", d, 24)[0]
    cmdline = _cstr(d[28 : 28 + 2048])
    header_size, dtb_size = struct.unpack_from("<II", d, 2096)

    bootconfig = ""
    if hv >= 4:
        vrt_size, _num, _entry, bc_size = struct.unpack_from("<IIII", d, 2112)

        def pa(n):
            return (n + page_size - 1) // page_size * page_size

        off = pa(header_size) + pa(vrsize) + pa(dtb_size) + pa(vrt_size)
        if bc_size and off + bc_size <= len(d):
            bootconfig = d[off : off + bc_size].decode("utf-8", "replace").strip()
    return f"vendor_boot.img (header v{hv})", cmdline, bootconfig


def inspect(path):
    try:
        with open(path, "rb") as f:
            d = f.read()
    except OSError as e:
        print(f"  !! cannot read {path}: {e}")
        return

    magic = d[:8]
    parts = []
    if magic == b"ANDROID!":
        label, cmd = read_boot(d)
        parts.append(("cmdline", cmd))
    elif magic == b"VNDRBOOT":
        label, cmd, bc = read_vendor_boot(d)
        parts.append(("cmdline", cmd))
        if bc:
            parts.append(("bootconfig", bc))
    else:
        return  # not a boot image; skip silently

    print(f"\n=== {os.path.basename(path)} — {label} ===")
    blob = []
    for name, val in parts:
        print(f"  [{name}] {val if val else '(empty)'}")
        blob.append(val)

    hits = [
        t
        for t in re.split(r"[\s\n]+", " ".join(blob))
        if t and FLAG_RE.search(t)
    ]
    print(f"  >> mitigation-related: {hits if hits else 'NONE'}")


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    for target in argv:
        if os.path.isdir(target):
            for root, _dirs, files in os.walk(target):
                for fn in sorted(files):
                    if fn.lower().endswith(".img"):
                        inspect(os.path.join(root, fn))
        else:
            inspect(target)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
