# Building the optimized Pong kernel

## What this is

A synthesis of the best-verified pieces from the 17-kernel survey in
`device/kernels/README.md`. Nothing here is novel kernel work — it combines
things already proven to run on this device, plus one toolchain change
nobody has combined with this base.

## Design in one paragraph

Start from **arter97 r45b2** because it is the only surveyed kernel with
both MGLRU and the built-in Qualcomm power stack (WALT, memlat, LPM idle
governor, Adreno TZ + GPU bandwidth governors, LMH thermal). Add **DAMON**,
which arter97 lacks and every other kernel has, and which is already in ACK
android12-5.10 so it costs a config flip rather than a backport. Make
**BBR** the default congestion control. Then build it with the **PGO + BOLT
+ MLGO** Android toolchain that WildKernels and Zixine use — the single
largest untapped lever, and one no CLO-based Pong kernel currently uses.

## Ingredients and provenance

| Piece | From | Cost |
|---|---|---|
| MGLRU | already in arter97 r45b2 | free |
| QCOM power stack | in the tree, but `=m` and inert until `MODULES` is restored | one source patch |
| DAMON | config flip (code is in ACK android12-5.10) | free |
| BBR default | config flip | free |
| PGO/BOLT/MLGO toolchain | WildKernels / Zixine build setup | build-side only |
| zram writeback off | arter97's 12 GB reasoning | free |

## Build

Verified end-to-end on the GCE builder. Do not substitute
`arch/arm64/configs/defconfig` for the root-level `defconfig` — they are
different files and the former does not build this kernel.

```sh
git clone --depth 1 -b master \
    https://github.com/arter97/android_kernel_nothing_sm8475 pong
git clone --depth 1 -b kernel-optimized \
    https://github.com/Omargamal7/notmuch2 cfg
cd pong && cat version          # must print r45b2

# required source patch (see "Source patches" below)
patch -p1 < ../cfg/patches/kernel-optimized/0001-mm-vmalloc-drop-orphaned-map_kernel_range-export.patch

# stamp 4.1, not 4.0 — anti-rollback
sed -i 's/^export OS=.*/export OS="16.0.0"/;s/^export SPL=.*/export SPL="2026-06"/' build_kernel.sh

# the FULL LLVM toolset is mandatory: with GNU ar/nm the LTO gate fails
# silently and takes CFI with it. Do NOT pass LLVM=1 (Makefile:401 has
# `override LLVM_PATH :=` pointing at arter97's home directory).
TOOLS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy \
       OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip \
       HOSTCC=gcc LLVM_IAS=1"

cp defconfig .config
scripts/kconfig/merge_config.sh -m .config \
    ../cfg/patches/kernel-optimized/pong_optimized.fragment
make ARCH=arm64 $TOOLS olddefconfig

# GATE — do not build if either check fails
grep -q '^CONFIG_LTO_CLANG_THIN=y' .config || echo "FATAL: LTO off"
grep -q '^CONFIG_QCOM_KGSL=y'      .config || echo "FATAL: no GPU driver"

make ARCH=arm64 $TOOLS -j$(nproc) Image.gz
./build_kernel.sh skip          # ramdisk + mkbootimg, kernel already built
```

Build on the GCE kernel-builder VM. Note its root disk is small — the 200 GB
`/dev/sdb` has no fstab entry and must be mounted manually
(`mount /dev/sdb /mnt/build`).

## Verify before flashing

Run the survey tooling against the output — it should show the union of
features, which is the whole point:

```sh
python3 scripts/kernel-survey/kscan.py /tmp/cfg out/arch/arm64/boot/Image
strings -n 5 out/arch/arm64/boot/Image | grep -ciE 'lru_gen|damon|memlat|waltgov'
```

Expect non-zero for **all four**. arter97 scores 3/0/45/5 (no DAMON);
Meteoric scores 0/25/45/5 (no MGLRU). This build is the first with both.

## Test

`fastboot boot` first — it runs the image without writing the partition, so
a bad build is one reboot away rather than a recovery job:

```sh
fastboot boot out/boot.img          # do NOT flash yet
adb shell cat /sys/kernel/mm/lru_gen/enabled     # MGLRU live
adb shell cat /sys/kernel/mm/damon/admin/kdamonds/nr_kdamonds 2>/dev/null
adb shell sysctl net.ipv4.tcp_congestion_control # expect bbr
adb shell cat /proc/pressure/memory              # PSI under load
```

Only flash after a `fastboot boot` session survives normal use.

## Known unknowns

- **Vendor symbol names** in the QCOM block are from binary strings, not
  from arter97's Kconfig. Verify each against the tree; some may differ or
  not exist there, in which case they are already built in and the assertion
  is redundant rather than wrong.
- **KMI**: MGLRU and DAMON touch `mm/` only, so no KMI symbols move and
  vendor blobs are unaffected. The QCOM entries are assertions of existing
  state, not changes. If a rebase makes any of them `=m`, stop and rethink —
  that means the base changed out from under this fragment.
- **Root**: arter97 r45b2 ships a KernelSU variant. Building from the plain
  tree gives no root; adding KSU in LKM mode is the modular option, and on
  pong that patches `boot` (there is no `init_boot` partition). GKI-mode KSU
  images take priority over LKM, so don't stack them.
- **Nothing here is benchmarked.** The reasoning is from static analysis of
  17 kernels. Treat the first build as a hypothesis to measure, not a
  finished tune.

## Source patches

`0001-mm-vmalloc-drop-orphaned-map_kernel_range-export.patch` must be applied
before building. It removes a dangling `EXPORT_SYMBOL_GPL` for a function that
no longer exists in arter97's tree — harmless for him because
`CONFIG_LAZY_INITCALL=y` disables modules and neuters `EXPORT_SYMBOL*`, but a
hard build failure once `CONFIG_MODULES=y` is restored (which this config
requires, or the GPU driver isn't built at all).

```sh
cd <arter97 tree>
patch -p1 < patches/kernel-optimized/0001-mm-vmalloc-drop-orphaned-map_kernel_range-export.patch
```
