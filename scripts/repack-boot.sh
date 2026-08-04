#!/usr/bin/env bash
# Repacks firmware/boot-unpacked/ back into a flashable boot.img under out/.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$repo_root/firmware/boot-unpacked"
out_dir="$repo_root/out"

command -v magiskboot >/dev/null || { echo "magiskboot not found on PATH" >&2; exit 1; }
[[ -d "$work_dir" ]] || { echo "run scripts/unpack-boot.sh first" >&2; exit 1; }

mkdir -p "$out_dir"
cd "$work_dir"
magiskboot repack "$repo_root/firmware/extracted/boot.img"
mv new-boot.img "$out_dir/boot.img"

echo "Repacked -> $out_dir/boot.img"
