#!/usr/bin/env bash
# Orchestrates a build for the current branch: fetch stock firmware if needed,
# extract it, apply this branch's patches/, repack, and drop output in out/.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

source <(grep -E '^source_type=' VERSION)

ls firmware/* >/dev/null 2>&1 || ./scripts/fetch-firmware.sh
if [[ ! -d firmware/extracted ]]; then
  if [[ "$source_type" == "ota-zip" ]]; then
    ./scripts/extract-payload.sh
  else
    ./scripts/extract-images.sh
  fi
fi

mkdir -p out

touches_boot_ramdisk=false
touches_vendor_ramdisk=false
[[ -d patches/ramdisk ]] && touches_boot_ramdisk=true
[[ -d patches/vendor-ramdisk ]] && touches_vendor_ramdisk=true

if $touches_boot_ramdisk || $touches_vendor_ramdisk; then
  ./scripts/unpack-boot.sh
  $touches_boot_ramdisk && cp -a patches/ramdisk/. firmware/boot-unpacked/boot-ramdisk/
  $touches_vendor_ramdisk && cp -a patches/vendor-ramdisk/. firmware/boot-unpacked/vendor_boot-ramdisk/
  ./scripts/repack-boot.sh "$touches_boot_ramdisk" "$touches_vendor_ramdisk"
else
  echo "No boot/vendor_boot ramdisk patches for this branch."
fi

if ! $touches_boot_ramdisk && [[ -f firmware/extracted/boot.img ]]; then
  cp firmware/extracted/boot.img out/boot.img
fi
if ! $touches_vendor_ramdisk && [[ -f firmware/extracted/vendor_boot.img ]]; then
  cp firmware/extracted/vendor_boot.img out/vendor_boot.img
fi

if [[ -d patches/system-overlay ]]; then
  echo "patches/system-overlay present but rebuilding system/vendor/product images is not implemented by this script yet -- apply those changes manually." >&2
fi

echo "Build output in ./out"
