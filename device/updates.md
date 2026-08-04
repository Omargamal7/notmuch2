# Build history

## Tracked: `Pong_B4.1-260618-1026` (current)

Security patch 2026-06-01. Not published as a full OTA anywhere — only as:

1. An incremental/delta OTA from `Pong_B4.1-260414-1749`
   (`android.googleapis.com/packages/ota-api/package/...`), whose
   `payload.bin` uses `PUFFDIFF` operations on the `system`/`vendor`/`boot`
   partitions. No available tool (`payload-dumper-go`, the `payload_dumper`
   pip package) implements `PUFFDIFF` — only Google's `puffin` (AOSP C++,
   not packaged anywhere) does, so this path was abandoned.
2. **What's actually used**: the GitHub release
   [`spike0en/nothing_archive` tag `Pong_B4.1-260618-1026`](https://github.com/spike0en/nothing_archive/releases/tag/Pong_B4.1-260618-1026)
   publishes all 36 partitions pre-extracted as three 7z archives
   (`image-boot.7z`, `image-firmware.7z`, `image-logical.7z.001-003`).
   `scripts/fetch-firmware.sh` + `scripts/extract-images.sh` pull and
   verify these directly — no OTA/payload parsing needed at all.

Verified: partition set is 1:1 identical (36/36, no additions or removals)
with the previous build; all extracted images checksum-verified in
`device/checksums/Pong_B4.1-260618-1026.sha256` (computed locally after
extraction — the release's own `hash.sha256` asset uses a short-lived
signed URL that had already expired by the time it was fetched).

## Previous: `Pong_B4.1-260414-1749`

Newest **full OTA** (`payload.bin`) published on archive.org
(`nothing-archive/spike0en/fullota/pong/`) at the time. Superseded by
`260618-1026` above. Still useful as the reference for the OTA-zip based
flow (`scripts/fetch-firmware.sh` variant for a `source_type=ota-zip`
build + `scripts/extract-payload.sh`), which some future build may again
require if no split-image release is published for it.
