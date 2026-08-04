#!/usr/bin/env bash
# Downloads the firmware for the build pinned in VERSION into firmware/
# (gitignored). Supports the two source types seen so far:
#   - github-release-images: per-partition 7z assets on a GitHub release
#     (canonical /releases/download/<tag>/<asset> — always redirects to a
#     freshly-signed CDN link, unlike a copied browser URL, so it doesn't
#     expire)
#   - ota-zip: a single full OTA zip (payload.bin), checksum-verified
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/VERSION"
out_dir="$repo_root/firmware"
mkdir -p "$out_dir"

# shellcheck source=/dev/null
source <(grep -E '^(build|source_type|source_release|source_url|sha256)=' "$version_file")

case "$source_type" in
  github-release-images)
    base_url="${source_release/\/tag\///download/}"
    assets=(
      "${build}-image-boot.7z"
      "${build}-image-firmware.7z"
      "${build}-image-logical.7z.001"
      "${build}-image-logical.7z.002"
      "${build}-image-logical.7z.003"
    )
    for asset in "${assets[@]}"; do
      dest="$out_dir/$asset"
      if [[ -f "$dest" ]]; then
        echo "Already present: $dest"
      else
        echo "Fetching $asset"
        curl -L --fail -o "$dest" "$base_url/$asset"
      fi
    done
    ;;
  ota-zip)
    zip_path="$out_dir/${build}.zip"
    if [[ -f "$zip_path" ]]; then
      echo "Already present: $zip_path"
    else
      echo "Fetching $source_url"
      curl -L --fail -o "$zip_path" "$source_url"
    fi
    echo "${sha256:-}  $zip_path" | sha256sum -c -
    ;;
  *)
    echo "unknown source_type '$source_type' in VERSION" >&2
    exit 1
    ;;
esac

echo "OK: assets in $out_dir"
