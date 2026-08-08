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

## Boot image structure (verified against a real extracted `Pong_B4.1-260618-1026`)

Boot image header **v4** (GKI split boot/vendor_boot):

- `boot.img` (100,663,296 B / partition-size-padded) — kernel (46.9 MB) +
  a **generic, device-agnostic** ramdisk (`lz4 -l` compressed, 1.38 MB →
  2.53 MB cpio: `init`, empty mount points, a GSI-identifying
  `system/etc/ramdisk/build.prop`). Not useful for device customization.
- `vendor_boot.img` (100,663,296 B / partition-size-padded) — dtb (6.65 MB),
  bootconfig (85 B), one vendor ramdisk fragment (`lz4 -l` compressed,
  11.28 MB → 39.06 MB cpio). **This carries the real device-specific
  content**:
  - `first_stage_ramdisk/fstab.qcom` — real partition/mount table (avb,
    dm-verity, encryption flags per partition)
  - `first_stage_ramdisk/adb_debug_ndebug.prop` — AOSP's standard
    force-debuggable GSI mechanism: dormant unless `/force_debuggable`
    exists at the ramdisk root *and* the bootloader is unlocked, then
    loaded with highest priority (`ro.adb.secure=0`, `ro.debuggable=1`).
    See the `adb-root` branch.
  - `avb/*.avbpubkey` — GSI AVB public keys referenced from `fstab.qcom`
  - `lib/modules/*.ko` — out-of-tree kernel modules (this is where they'd
    need to land for `kernel-optimized`'s `LAZY_INITCALL`/`=m` modules —
    not something this branch touches)
  - Both `boot.img` and `vendor_boot.img` end in an AVB footer (magic
    `AVBf` at `partition_size - 64`) pointing at a small per-partition
    vbmeta blob. `scripts/repack-boot.sh` does not reproduce this footer —
    see `patches/README.md` for what that means in practice.

Toolchain used to verify all of the above (all apt-installable, no
Android-specific binary needed): `p7zip-full`, `mkbootimg` (ships both
`mkbootimg` and `unpack_bootimg`), `cpio`, `lz4`.
