# Customization workflow

`main` is the stock baseline: scaffold, build scripts, and the pinned
`VERSION` for Nothing OS Pong (Nothing Phone (2)) build `B4.1-260414-1749`.
It carries no patches — `scripts/build.sh` on `main` just fetches, extracts,
and re-emits the stock `boot.img` unchanged.

The actual OTA package is **not** committed to git (5+ GB, exceeds normal
git/GitHub limits). `scripts/fetch-firmware.sh` downloads it into the
gitignored `firmware/` directory, verified against the checksum in
`VERSION`, so every branch builds from the same known-good stock image.

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
- `scripts/unpack-boot.sh` / `repack-boot.sh` need `magiskboot` on `PATH` (grab it from a Magisk release zip).

`fetch-firmware.sh` and `extract-payload.sh` have been run end-to-end
against the pinned build and verified (checksum match, all 34 partitions
dumped). `unpack-boot.sh`/`repack-boot.sh` depend on `magiskboot`, which
isn't available in this environment — verify those against your own
toolchain before flashing anything to a real device.

See `device/updates.md` for a newer build known to exist only as an
incremental OTA, and why it isn't wired up yet.
