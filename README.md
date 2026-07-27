# notmuch2

Customized Nothing OS for **Pong** (Nothing Phone (2), codename `spike0en`),
built from the stock OTA and modified per-branch.

- `main` — stock baseline: scaffold, build scripts, pinned `VERSION`, no customization
- customization branches — one concern each, patches only (see `CUSTOMIZATION.md`)

## Layout

| Path | Purpose |
|---|---|
| `VERSION` | Pinned stock build + checksum |
| `device/pong.md` | Device/partition reference |
| `scripts/` | fetch → extract → patch → repack pipeline |
| `patches/` | Per-branch customizations (empty on `main`) |
| `firmware/` | Gitignored working dir for downloaded/extracted blobs |

See `CUSTOMIZATION.md` for the branch workflow.

