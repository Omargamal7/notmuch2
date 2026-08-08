#!/usr/bin/env bash
# Extracts the 7z assets fetched by fetch-firmware.sh into per-partition raw
# images under firmware/extracted/, then verifies them against the checksums
# pinned in VERSION's partition_checksums file.
#
# Each archive is optional here: a branch that only patches the boot/
# vendor_boot ramdisk doesn't need the ~4.8GB logical (system/vendor/
# product) or firmware archives fetched or extracted, so any archive
# missing from firmware/ is skipped rather than failing the whole build.
# Checksums are verified only for the partitions actually extracted.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/VERSION"
fw_dir="$repo_root/firmware"
extract_dir="$fw_dir/extracted"

# shellcheck source=/dev/null
source <(grep -E '^(build|partition_checksums)=' "$version_file")

command -v 7z >/dev/null || { echo "7z (p7zip-full) not found on PATH" >&2; exit 1; }

mkdir -p "$extract_dir"

extract_if_present() {
  local archive="$fw_dir/$1"
  if [[ -f "$archive" ]]; then
    7z x -y -o"$extract_dir" "$archive" >/dev/null
  else
    echo "Skipping $1 (not fetched)"
  fi
}

extract_if_present "${build}-image-boot.7z"
extract_if_present "${build}-image-firmware.7z"
# 7z auto-continues into .002/.003 alongside .001 for this split archive.
extract_if_present "${build}-image-logical.7z.001"

echo "Verifying partition checksums for extracted partitions..."
present_checksums="$(mktemp)"
trap 'rm -f "$present_checksums"' EXIT
while IFS= read -r line; do
  file="${line#*  }"
  [[ -f "$extract_dir/$file" ]] && echo "$line" >> "$present_checksums"
done < "$repo_root/$partition_checksums"
if [[ -s "$present_checksums" ]]; then
  (cd "$extract_dir" && sha256sum -c "$present_checksums")
else
  echo "No extracted partitions matched $partition_checksums" >&2
  exit 1
fi

echo "Extracted + verified partitions in $extract_dir"
