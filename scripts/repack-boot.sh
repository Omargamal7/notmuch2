#!/usr/bin/env bash
# Repacks firmware/boot-unpacked/{boot,vendor_boot}-ramdisk/ (after build.sh
# has applied a branch's patches/ onto them) back into flashable images
# under out/. Reuses the reconstruction args unpack-boot.sh recorded from
# the original image, swapping in the freshly repacked ramdisk.
#
# Usage: repack-boot.sh <repack boot: true|false> <repack vendor_boot: true|false>
# Only repacks the images a branch actually patched; build.sh copies the
# other one through unmodified.
set -euo pipefail

repack_boot="${1:?repack-boot.sh needs true/false for boot}"
repack_vendor_boot="${2:?repack-boot.sh needs true/false for vendor_boot}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$repo_root/firmware/boot-unpacked"
out_dir="$repo_root/out"
gki_stub="$repo_root/scripts/vendor/gki-stub"

for tool in mkbootimg cpio lz4; do
  command -v "$tool" >/dev/null || { echo "$tool not found on PATH -- apt install mkbootimg cpio lz4" >&2; exit 1; }
done

mkdir -p "$out_dir"

# repack_one <name> <output flag> <output filename>
repack_one() {
  local name="$1" out_flag="$2" out_file="$3"
  local rd_dir="$work_dir/$name-ramdisk"
  [[ -d "$rd_dir" ]] || { echo "no unpacked ramdisk for $name -- run unpack-boot.sh first" >&2; exit 1; }

  local new_cpio="$work_dir/$name.new-ramdisk.cpio"
  local new_ramdisk="$work_dir/$name.new-ramdisk"
  # cpio newc, no leading "./", matches the original ramdisk's own format
  # (verified against a real Pong vendor_ramdisk: `file` reports "ASCII
  # cpio archive (SVR4 with no CRC)" == newc without per-entry checksums).
  ( cd "$rd_dir" && find . -mindepth 1 | sed 's|^\./||' | cpio -o -H newc 2>/dev/null ) > "$new_cpio"
  # -l: legacy/kernel LZ4 framing, matching the original (`file` reports
  # plain "LZ4 compressed data", not the modern LZ4 frame format).
  lz4 -l -9 -f "$new_cpio" "$new_ramdisk" >/dev/null

  local args
  args="$(cat "$work_dir/$name.mkbootimg-args")"
  local ramdisk_source
  ramdisk_source="$(cat "$work_dir/$name.ramdisk-source")"

  # NOTE: for vendor_boot, --vendor_ramdisk_fragment is an `append`-style
  # flag paired positionally with a following --ramdisk_name (required) --
  # each occurrence defines one fragment table entry. Appending a second
  # --vendor_ramdisk_fragment does *not* override the first; it tries to add
  # an incomplete second fragment and mkbootimg rejects it (verified: errors
  # "required: --ramdisk_name"). Substitute the recorded source path inside
  # the captured args instead, since this device has exactly one fragment.
  args="${args//$ramdisk_source/$new_ramdisk}"

  local extra
  extra="$(printf ' %s %q' "$out_flag" "$out_dir/$out_file")"
  PYTHONPATH="$gki_stub${PYTHONPATH:+:$PYTHONPATH}" bash -c "mkbootimg $args$extra"
  echo "Repacked -> $out_dir/$out_file"
}

[[ "$repack_boot" == "true" ]] && repack_one "boot" "--output" "boot.img"
[[ "$repack_vendor_boot" == "true" ]] && repack_one "vendor_boot" "--vendor_boot" "vendor_boot.img"

echo "Repack done."
