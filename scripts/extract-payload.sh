#!/usr/bin/env bash
# Pulls payload.bin out of the fetched OTA zip and dumps it into per-partition
# raw images under firmware/extracted/ using payload-dumper-go.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source <(grep -E '^build=' "$repo_root/VERSION")

zip_path="$repo_root/firmware/${build}.zip"
extract_dir="$repo_root/firmware/extracted"

[[ -f "$zip_path" ]] || { echo "run scripts/fetch-firmware.sh first" >&2; exit 1; }

if ! command -v payload-dumper-go >/dev/null; then
  echo "installing payload-dumper-go..."
  GOBIN="$(go env GOPATH)/bin" go install github.com/ssut/payload-dumper-go@latest
  export PATH="$(go env GOPATH)/bin:$PATH"
fi

mkdir -p "$extract_dir"
unzip -p "$zip_path" payload.bin > "$repo_root/firmware/payload.bin"
payload-dumper-go -o "$extract_dir" "$repo_root/firmware/payload.bin"

echo "Extracted partitions in $extract_dir"
