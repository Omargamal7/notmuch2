# Known updates beyond the pinned baseline

`VERSION` pins `Pong_B4.1-260414-1749` — the newest **full** OTA package
published for this device (checked against the full archive listing at
`nothing-archive/spike0en/fullota/pong/`; nothing newer exists as a full
image yet).

A newer build is known to exist, but only as an **incremental/delta** OTA:

| Field | Value |
|---|---|
| Target build | `Pong_B4.1-260618-1026` |
| Security patch | 2026-06-01 (vs. 2026-04-01 on the pinned baseline) |
| Source build (delta base) | `Pong_B4.1-260414-1749` — matches our pinned `VERSION` |
| Package | `https://android.googleapis.com/packages/ota-api/package/821762bba7df49d1648ab91eef5c98574f20e740.zip` |
| sha256 | `613fb104981e5129cec14b4c881b46e138adbfffba99b9cb9cdf94675a2ce56e` |

Delta OTAs encode `payload.bin` operations (`BSDIFF`/`PUFFDIFF`/`COPY`/...)
against the *source* partition images rather than shipping full images.
`payload-dumper-go` (used by `scripts/extract-payload.sh`) only dumps full
payloads — it has no old-partition/diff mode — so this delta can't be
applied with the current tooling. Options, not yet implemented here:

- Wait for Nothing/archive.org to publish a full OTA for `260618-1026`, then
  just bump `VERSION`.
- Apply the delta properly using AOSP's `update_engine`/`update_payload`
  tooling (needs the exact source partition images as input).

Don't wire up an untested delta-apply path — get a full OTA when one shows
up, or verify a delta-apply script against a real device/emulator before
trusting it.
