# Customization workflow

`main` is the stock baseline: scaffold, build scripts, and the pinned
`VERSION` for Nothing OS Pong (Nothing Phone (2)), currently build
`B4.1-260618-1026`. It carries no patches — `scripts/build.sh` on `main`
just fetches, extracts, and re-emits the stock `boot.img`/`vendor_boot.img`
unchanged.

Firmware binaries are **not** committed to git (multi-GB, exceeds normal
git/GitHub limits). `scripts/fetch-firmware.sh` downloads them into the
gitignored `firmware/` directory based on `VERSION`'s `source_type`:

- `github-release-images` (current): per-partition 7z assets from a GitHub
  release. `scripts/extract-images.sh` extracts them and verifies every
  partition against `device/checksums/<build>.sha256`.
- `ota-zip`: a single full OTA zip. `scripts/extract-payload.sh` pulls
  `payload.bin` out and dumps partitions with `payload-dumper-go`.

`scripts/build.sh` picks the right extractor automatically from
`VERSION`'s `source_type`.

## Adding a customization

```sh
git checkout -b <feature-name> main
# edit files under patches/ (see patches/README.md)
./scripts/build.sh
git add patches/
git commit -m "..."
git push -u origin <feature-name>
```

Keep one concern per branch (e.g. `debloat`, `kernel-tweaks`, `theme-x`) so
branches can be reviewed, rebased on a new stock `VERSION`, or cherry-picked
independently. When Nothing ships a newer build, bump `VERSION` on `main`
and rebase customization branches on top.

## Setup

- `scripts/extract-payload.sh` needs Go (`go install .../payload-dumper-go`) — installed automatically on first run.
- `scripts/extract-images.sh` needs `7z` (apt: `p7zip-full`).
- `scripts/unpack-boot.sh` / `repack-boot.sh` need `unpack_bootimg`/`mkbootimg`
  (apt: `mkbootimg`), `cpio`, and `lz4` — **not** `magiskboot`. All four are
  ordinary Ubuntu/Debian packages; nothing Android-specific to source
  separately. (Ubuntu's `mkbootimg` package has one packaging bug worth
  knowing about — see `patches/README.md`'s note on `scripts/vendor/gki-stub/`.)

Verified end-to-end this session, against the real pinned build, not just
read/scripted:

- `fetch-firmware.sh`'s `github-release-images` download path: the
  `/releases/download/<tag>/<asset>` URL it constructs does work from a
  sandboxed environment even when browsing `github.com` HTML pages is
  blocked — it 302s to a signed `release-assets.githubusercontent.com`
  URL, which isn't. Fetched `Pong_B4.1-260618-1026-image-boot.7z` for real
  (32,485,414 B).
- `extract-images.sh`: extracted that archive's 7 partitions
  (`boot`/`dtbo`/`recovery`/`vbmeta`/`vbmeta_system`/`vbmeta_vendor`/`vendor_boot`)
  and checksum-verified all 7 against `device/checksums/Pong_B4.1-260618-1026.sha256`
  — exact match.
- `unpack-boot.sh` / `repack-boot.sh`: unpacked the real `vendor_boot.img`
  and `boot.img`, applied a one-file ramdisk overlay to each, repacked, and
  re-unpacked the result to confirm the overlay landed and every original
  ramdisk entry (fstab, avb keys, kernel modules, dtb, bootconfig, cmdline)
  survived unchanged. See `patches/README.md` for the mechanics and the one
  real bug this surfaced (`--vendor_ramdisk_fragment` isn't override-safe).

Not verified this session: the `firmware.7z` and multi-part `logical.7z`
archives (~4.8 GB, not needed by any ramdisk-only branch) weren't fetched
or extracted; `scripts/extract-payload.sh`'s OTA-zip path wasn't exercised
(no current build uses it); and no repacked image has been flashed to or
booted on real hardware (no device available in this environment) — see
`patches/README.md`'s AVB-footer note for what that specifically means.

See `device/updates.md` for the build history and why the current build
came from GitHub release assets rather than an OTA payload.
