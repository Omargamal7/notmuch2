#!/usr/bin/env bash
# Unpacks boot.img and vendor_boot.img (from firmware/extracted/) into
# firmware/boot-unpacked/, decompressing each ramdisk into a browsable/
# patchable directory.
#
# Pong ships boot header v4 (GKI): boot.img's ramdisk is the generic,
# device-agnostic GKI ramdisk; the real device init/fstab/props live in
# vendor_boot.img's vendor ramdisk instead. Both are unpacked here since a
# branch may want either -- see patches/README.md.
#
# Requires `unpack_bootimg`/`mkbootimg` (apt: mkbootimg), `cpio`, and `lz4`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extract_dir="$repo_root/firmware/extracted"
work_dir="$repo_root/firmware/boot-unpacked"

for tool in unpack_bootimg cpio lz4 file; do
  command -v "$tool" >/dev/null || { echo "$tool not found on PATH -- apt install mkbootimg cpio lz4 file" >&2; exit 1; }
done
[[ -f "$extract_dir/boot.img" ]] || { echo "run scripts/extract-images.sh (or extract-payload.sh) first" >&2; exit 1; }

rm -rf "$work_dir" && mkdir -p "$work_dir"

# Android ramdisks may be gzip, lz4 (legacy/kernel framing), zstd, or
# uncompressed cpio; detect and decompress whichever this one is.
decompress_ramdisk() {
  local src="$1" dst="$2"
  case "$(file -b "$src")" in
    "LZ4 compressed"*) lz4 -d -f "$src" "$dst" >/dev/null ;;
    "gzip compressed"*) gzip -dc "$src" > "$dst" ;;
    "Zstandard compressed"*) zstd -d -f "$src" -o "$dst" ;;
    "ASCII cpio archive"*) cp "$src" "$dst" ;;
    *) echo "unrecognized ramdisk compression for $src: $(file -b "$src")" >&2; exit 1 ;;
  esac
}

# unpack_one <image path> <name> <ramdisk filename glob (relative to unpack out dir)>
unpack_one() {
  local img="$1" name="$2" ramdisk_glob="$3"
  [[ -f "$img" ]] || return 0
  local out="$work_dir/$name"
  mkdir -p "$out"
  unpack_bootimg --boot_img "$img" --out "$out" --format mkbootimg > "$work_dir/$name.mkbootimg-args"

  local rd_file
  rd_file="$(ls "$out"/$ramdisk_glob 2>/dev/null | head -1 || true)"
  if [[ -n "$rd_file" && -s "$rd_file" ]]; then
    local rd_dir="$work_dir/$name-ramdisk"
    mkdir -p "$rd_dir"
    decompress_ramdisk "$rd_file" "$work_dir/$name.ramdisk.cpio"
    ( cd "$rd_dir" && cpio -idm < "$work_dir/$name.ramdisk.cpio" >/dev/null 2>&1 )
    echo "$rd_file" > "$work_dir/$name.ramdisk-source"
    echo "Unpacked $name -> $out (ramdisk contents -> $rd_dir)"
  else
    echo "Unpacked $name -> $out (no non-empty ramdisk)"
  fi
}

unpack_one "$extract_dir/boot.img" "boot" "ramdisk"
unpack_one "$extract_dir/vendor_boot.img" "vendor_boot" "vendor_ramdisk*"

echo "Unpacked into $work_dir"
