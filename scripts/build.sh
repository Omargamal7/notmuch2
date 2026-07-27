#!/usr/bin/env bash
# Orchestrates a build for the current branch: fetch stock firmware if needed,
# extract it, apply this branch's patches/, repack, and drop output in out/.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ls firmware/*.zip >/dev/null 2>&1 || ./scripts/fetch-firmware.sh
[[ -d firmware/extracted ]] || ./scripts/extract-payload.sh

if [[ -d patches/ramdisk || -d patches/system-overlay ]]; then
  ./scripts/unpack-boot.sh
  if [[ -d patches/ramdisk ]]; then
    cp -r patches/ramdisk/. firmware/boot-unpacked/ramdisk/ 2>/dev/null || true
  fi
  ./scripts/repack-boot.sh
else
  echo "No patches for this branch — nothing to customize, stock boot.img only."
  mkdir -p out
  cp firmware/extracted/boot.img out/boot.img
fi

echo "Build output in ./out"
