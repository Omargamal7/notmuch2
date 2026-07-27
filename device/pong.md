# Device: Pong (Nothing Phone (2))

| Field          | Value                                   |
|----------------|------------------------------------------|
| Codename       | `spike0en` / `Pong`                      |
| OS             | Nothing OS                               |
| Tracked build  | `Pong_B4.1-260414-1749` (see `VERSION`)  |
| Update type    | Full OTA (A/B, `payload.bin`)            |
| Source         | archive.org — `nothing-archive/spike0en/fullota/pong/` |

## Partition layout (A/B)

The full OTA package unpacks into a `payload.bin` (Chrome OS A/B update
payload format) containing the per-partition images, typically including:

- `boot`, `vendor_boot`, `dtbo`, `vbmeta`, `vbmeta_system`
- `system`, `vendor`, `product`, `system_ext`, `odm` (usually inside a `super` dynamic-partition image)

Run `scripts/extract-payload.sh` after fetching to dump these individually.
