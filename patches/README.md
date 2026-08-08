# patches/

Each customization branch keeps its changes here as small, reviewable files
rather than committing modified binary images:

- `vendor-ramdisk/` — files to overlay into `vendor_boot.img`'s ramdisk
  before repack. **This is where device-specific customization actually
  goes.** Pong ships boot image header v4 (GKI): `boot.img` carries a
  generic, device-agnostic ramdisk, while `vendor_boot.img`'s ramdisk holds
  the real `first_stage_ramdisk/` (fstab, debug props), `avb/` keys, and
  `lib/modules/*.ko` — verified by unpacking a real `Pong_B4.1-260618-1026`
  `vendor_boot.img`.
- `ramdisk/` — files to overlay into `boot.img`'s *generic* GKI ramdisk.
  Rarely useful on this device (it's the same device-agnostic content GKI
  ships on any Android 12+ device — see `device/pong.md`), but the pipeline
  supports it symmetrically.
- `system-overlay/` — files to overlay into the mounted `system`/`product`
  partition (e.g. `build.prop` edits, debloat lists, replaced APKs). Scaffolded
  but **not implemented yet** — `scripts/build.sh` warns and does nothing if
  this exists. Rebuilding `system`/`product` means resizing and rewriting a
  multi-GB ext4/erofs image, which needs more tooling
  (`erofs-utils`/`e2fsprogs`/loop-mount privileges) than has been wired up or
  verified so far.
- `*.patch` — unified diffs against stock config/source files. Not yet
  consumed by any script — reserved for future use.

`scripts/build.sh` applies whatever is present here on top of the stock
extraction and produces flashable output in `out/`. An empty `patches/`
directory (as on `main`) means "unmodified stock".

## The ramdisk overlay/repack loop, concretely

`scripts/unpack-boot.sh` and `scripts/repack-boot.sh` (called by
`build.sh`) use `unpack_bootimg`/`mkbootimg` (Debian/Ubuntu package:
`mkbootimg`) plus `cpio` and `lz4`, not `magiskboot` — verified working end
to end against a real downloaded `vendor_boot.img`:

1. `unpack_bootimg --format mkbootimg` unpacks the image *and* prints the
   exact flags needed to reconstruct it — captured to
   `firmware/boot-unpacked/<name>.mkbootimg-args`.
2. The ramdisk blob it extracts is `lz4 -l` (legacy/kernel framing)
   compressed `cpio` (format: `newc`, no leading `./`, no CRC — this is
   what a real Pong ramdisk actually is, not assumed). It gets decompressed
   and `cpio -idm`-extracted into `firmware/boot-unpacked/<name>-ramdisk/`,
   an ordinary directory you can `cp` files into (that's what `build.sh`
   does with your `patches/vendor-ramdisk/` files).
3. On repack, the directory is re-archived (`cpio -o -H newc`, stripping
   the `./` prefix `find` adds) and re-compressed (`lz4 -l -9`), then
   `mkbootimg` is invoked by textually substituting the new ramdisk path
   into the args captured in step 1 for the original one, plus an output
   flag.
   - Note: for `vendor_boot.img`, `--vendor_ramdisk_fragment` is an
     `append`-style flag paired with a following `--ramdisk_name` — just
     appending a second `--vendor_ramdisk_fragment <newpath>` does **not**
     override the first (mkbootimg rejects it: "required: --ramdisk_name").
     That's why the args are edited in place rather than appended to.
4. A repacked `vendor_boot.img` deliberately does **not** carry an AVB
   footer/vbmeta blob the way the stock one does (the stock image has one
   at the fixed `partition_size - 64` offset — `mkbootimg` doesn't add one
   here since we don't pass `--gki_signing_key`). This matches how any
   unsigned/custom boot image behaves on an unlocked bootloader (same as a
   Magisk-patched boot image) — expect an orange/unlocked verified-boot
   warning at boot, not a hard failure. Not independently confirmed on
   real hardware this session (no device available) — verified structurally
   (re-parses correctly, all original ramdisk entries preserved, only the
   overlaid files differ) but not verified to actually boot.

Ubuntu's `mkbootimg` package (1:34.0.4-1build3 on noble) has a packaging
bug: it imports a `gki` submodule it never ships, and errors immediately
even when you don't need GKI signing. `scripts/vendor/gki-stub/` is a
minimal stub that satisfies the import without doing anything real —
`repack-boot.sh` points `PYTHONPATH` at it. See the comment in
`scripts/vendor/gki-stub/gki/generate_gki_certificate.py` for the full
story.
