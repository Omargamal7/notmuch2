#!/usr/bin/env python3
"""Extract kernel banner + embedded IKCONFIG from raw kernel Images / boot.imgs."""
import gzip
import os
import re
import struct
import sys

BANNER = re.compile(rb"Linux version (\d+\.\d+\.\d+[^\s]*) \(([^)]*)\) \((.*?)\) (#\d+[^\x00\n]*)")


def maybe_gunzip(d):
    """Return the decompressed payload if this is a gzip-wrapped Image."""
    i = d.find(b"\x1f\x8b\x08")
    if i == -1:
        return d
    try:
        return gzip.decompress(d[i:])
    except Exception:
        try:  # truncated tail is normal; stream what we can
            return gzip.GzipFile(fileobj=__import__("io").BytesIO(d[i:])).read()
        except Exception:
            return d


def kernel_from_boot(d):
    if d[:8] != b"ANDROID!":
        return d
    ksize = struct.unpack_from("<I", d, 8)[0]
    hsize = struct.unpack_from("<I", d, 16)[0]
    off = (hsize + 4095) // 4096 * 4096
    return d[off : off + ksize]


def ikconfig(d):
    """Pull the gzip blob between IKCFG_ST/IKCFG_ED (skip code refs to the marker)."""
    for m in re.finditer(b"IKCFG_ST", d):
        s = m.end()
        if d[s : s + 3] != b"\x1f\x8b\x08":
            continue
        e = d.find(b"IKCFG_ED", s)
        try:
            return gzip.decompress(d[s : e if e != -1 else len(d)])
        except Exception:
            continue
    return None


def scan(path):
    d = open(path, "rb").read()
    d = kernel_from_boot(d)
    d = maybe_gunzip(d)

    m = BANNER.search(d)
    banner = {}
    if m:
        banner = {
            "version": m.group(1).decode("utf-8", "replace"),
            "builder": m.group(2).decode("utf-8", "replace"),
            "toolchain": m.group(3).decode("utf-8", "replace"),
            "buildinfo": m.group(4).decode("utf-8", "replace"),
        }
    cfg = ikconfig(d)
    return banner, cfg


if __name__ == "__main__":
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    for path in sys.argv[2:]:
        name = os.path.basename(os.path.dirname(path)) or os.path.basename(path)
        if os.path.basename(path) not in ("Image", "Image.gz"):
            name = os.path.basename(path)
        try:
            banner, cfg = scan(path)
        except Exception as e:
            print(f"!! {name}: {e}")
            continue
        print(f"\n=== {name} ===")
        if banner:
            print(f"  version   : {banner['version']}")
            tc = banner["toolchain"]
            tc = re.sub(r"\(https?://[^)]*\)", "", tc)
            print(f"  toolchain : {tc[:150]}")
            print(f"  build     : {banner['buildinfo'][:90]}")
        else:
            print("  (no banner found)")
        if cfg:
            out = os.path.join(outdir, name + ".config")
            open(out, "wb").write(cfg)
            n = sum(1 for l in cfg.splitlines() if re.match(rb"CONFIG_\S+=(y|m)", l))
            print(f"  config    : {len(cfg.splitlines())} lines, {n} enabled -> {out}")
        else:
            print("  config    : (no IKCONFIG embedded)")
