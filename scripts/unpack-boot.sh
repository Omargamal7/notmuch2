#!/usr/bin/env bash
# Unpacks boot.img (from firmware/extracted/) into kernel + ramdisk under
# firmware/boot-unpacked/, so the ramdisk contents are diffable/patchable.
# Requires `magiskboot` on PATH (ships in the Magisk app/zip).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
img="$repo_root/firmware/extracted/boot.img"
work_dir="$repo_root/firmware/boot-unpacked"

command -v magiskboot >/dev/null || { echo "magiskboot not found on PATH — grab it from a Magisk release" >&2; exit 1; }
[[ -f "$img" ]] || { echo "run scripts/extract-payload.sh first" >&2; exit 1; }

rm -rf "$work_dir" && mkdir -p "$work_dir"
cd "$work_dir"
magiskboot unpack "$img"

echo "Unpacked into $work_dir (kernel, ramdisk.cpio, ...)"
