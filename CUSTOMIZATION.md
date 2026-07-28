# Customization workflow

`main` is the stock baseline: scaffold, build scripts, and the pinned
`VERSION` for Nothing OS Pong (Nothing Phone (2)), currently build
`B4.1-260618-1026`. It carries no patches — `scripts/build.sh` on `main`
just fetches, extracts, and re-emits the stock `boot.img` unchanged.

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
- `scripts/extract-images.sh` needs `7z` (`p7zip-full`).
- `scripts/unpack-boot.sh` / `repack-boot.sh` need `magiskboot` on `PATH` (grab it from a Magisk release zip), not available in this environment — verify those against your own toolchain before flashing anything to a real device.

`fetch-firmware.sh` + `extract-images.sh` have been run end-to-end for the
current pinned build (all 36 partitions extracted and checksum-verified).
`fetch-firmware.sh`'s `github-release-images` download path itself
couldn't be re-verified live from this environment — GitHub access here is
scoped to this repo only — but the URLs it constructs were checked by hand
against the real release assets during development.

See `device/updates.md` for the build history and why the current build
came from GitHub release assets rather than an OTA payload.
