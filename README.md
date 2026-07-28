# notmuch2

Customized Nothing OS for **Pong** (Nothing Phone (2), codename `spike0en`),
built from the stock firmware and modified per-branch.

- `main` — stock baseline: scaffold, build scripts, pinned `VERSION` (currently `Pong_B4.1-260618-1026`), no customization
- customization branches — one concern each, patches only (see `CUSTOMIZATION.md`)

## Layout

| Path | Purpose |
|---|---|
| `VERSION` | Pinned stock build + source + checksums pointer |
| `device/pong.md` | Device/partition reference |
| `device/checksums/` | Per-partition sha256 for each tracked build |
| `device/updates.md` | Build history / provenance |
| `scripts/` | fetch → extract → patch → repack pipeline |
| `patches/` | Per-branch customizations (empty on `main`) |
| `firmware/` | Gitignored working dir for downloaded/extracted blobs |

See `CUSTOMIZATION.md` for the branch workflow.

