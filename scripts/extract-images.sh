#!/usr/bin/env bash
# Extracts the 7z assets fetched by fetch-firmware.sh into per-partition raw
# images under firmware/extracted/, then verifies them against the checksums
# pinned in VERSION's partition_checksums file.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/VERSION"
fw_dir="$repo_root/firmware"
extract_dir="$fw_dir/extracted"

# shellcheck source=/dev/null
source <(grep -E '^(build|partition_checksums)=' "$version_file")

command -v 7z >/dev/null || { echo "7z (p7zip-full) not found on PATH" >&2; exit 1; }

mkdir -p "$extract_dir"
7z x -y -o"$extract_dir" "$fw_dir/${build}-image-boot.7z" >/dev/null
7z x -y -o"$extract_dir" "$fw_dir/${build}-image-firmware.7z" >/dev/null
7z x -y -o"$extract_dir" "$fw_dir/${build}-image-logical.7z.001" >/dev/null

echo "Verifying partition checksums..."
(cd "$extract_dir" && sha256sum -c "$repo_root/$partition_checksums")

echo "Extracted + verified partitions in $extract_dir"
