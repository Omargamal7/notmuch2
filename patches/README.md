# patches/

Each customization branch keeps its changes here as small, reviewable files
rather than committing modified binary images:

- `ramdisk/` — files to overlay into the unpacked boot ramdisk before repack
  (e.g. `init.rc` tweaks, fstab changes)
- `system-overlay/` — files to overlay into the mounted `system`/`product`
  partition (e.g. `build.prop` edits, debloat lists, replaced APKs)
- `*.patch` — unified diffs against stock config/source files

`scripts/build.sh` applies whatever is present here on top of the stock
extraction and produces flashable output in `out/`. An empty `patches/`
directory (as on `main`) means "unmodified stock".
