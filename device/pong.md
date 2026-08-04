# Device: Pong (Nothing Phone (2))

| Field          | Value                                   |
|----------------|------------------------------------------|
| Codename       | `spike0en` / `Pong`                      |
| OS             | Nothing OS                               |
| Tracked build  | `Pong_B4.1-260618-1026` (see `VERSION`)  |
| Source         | GitHub release — `spike0en/nothing_archive`, per-partition 7z images |

## Partition layout

36 partitions, shipped (for the tracked build) as three 7z archives on the
GitHub release:

- `<build>-image-boot.7z` — `boot`, `dtbo`, `recovery`, `vbmeta*`, `vendor_boot`
- `<build>-image-firmware.7z` — SoC/modem firmware partitions (`abl`, `xbl*`, `tz`, `hyp`, `modem`, `dsp`, ...)
- `<build>-image-logical.7z.{001,002,003}` — dynamic/`super` partitions: `system`, `system_ext`, `vendor`, `vendor_dlkm`, `product`, `odm`

Run `scripts/fetch-firmware.sh` then `scripts/extract-images.sh` to get all
36 as raw `.img` files, verified against `device/checksums/<build>.sha256`.

Earlier builds (e.g. `Pong_B4.1-260414-1749`) were published as a single
full OTA `payload.bin` instead — see `device/updates.md` for that method
(`scripts/extract-payload.sh`), kept around for builds that only ship that
way.
