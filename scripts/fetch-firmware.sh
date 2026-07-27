#!/usr/bin/env bash
# Downloads the stock OTA package recorded in VERSION into firmware/ (gitignored)
# and verifies it against the checksum recorded there.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_file="$repo_root/VERSION"
out_dir="$repo_root/firmware"

# shellcheck source=/dev/null
source <(grep -E '^(build|source_url|sha256)=' "$version_file")

mkdir -p "$out_dir"
zip_path="$out_dir/${build}.zip"

if [[ -f "$zip_path" ]]; then
  echo "Already present: $zip_path"
else
  echo "Fetching $source_url"
  curl -L --fail -o "$zip_path" "$source_url"
fi

if [[ "$sha256" != "TBD" ]]; then
  echo "$sha256  $zip_path" | sha256sum -c -
else
  echo "warning: no checksum pinned in VERSION yet; skipping verification" >&2
fi

echo "OK: $zip_path"
