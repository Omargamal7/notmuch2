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
**BBR** the default congestion control. A PGO/BOLT/MLGO toolchain remains the
largest untapped lever, but the verified build used Debian clang 19.1.7 —
swapping the toolchain is a separate, still-untested step.

## Ingredients and provenance

| Piece | From | Cost |
|---|---|---|
| MGLRU | already in arter97 r45b2 | free |
| QCOM power stack (WALT, memlat, KGSL) | already in arter97 r45b2 as lazy-init `=m` | free |
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

# arter97's tree does NOT build as published: focaltech_touch needs firmware
# headers that were never committed. Source them from any other NP2 kernel
# tree, e.g. a Nothing OS 4.1 build tree (already on the VM):
cp -r /home/Admin/pong-nos41-kernel-build/drivers/input/touchscreen/focaltech_touch/include/firmware \
      drivers/input/touchscreen/focaltech_touch/include/

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
grep -q '^CONFIG_LRU_GEN=y'        .config || echo "FATAL: no MGLRU"
grep -q '^CONFIG_DAMON=y'          .config || echo "FATAL: no DAMON"

# Ensure pigz is installed (make dies with Error 127 otherwise)
sudo apt-get install -y pigz

make ARCH=arm64 $TOOLS -j$(nproc) Image.gz
./build_kernel.sh skip          # ramdisk + mkbootimg, kernel already built
# The final image is arter97-kernel-r45b2-boot.img (hardlinked to out/boot.img)
```

Build on the GCE kernel-builder VM. The build tree lives on the VM's 200 GB
disk at `/mnt/build/pong/`. An fstab entry mounts it automatically by UUID, so
no manual mount is needed.

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

## Variants

Three images, built on the same base:

| | difference | build |
|---|---|---|
| **A — balanced** (default) | `SHADOW_CALL_STACK`, `HARDENED_USERCOPY`, `INIT_STACK_ALL_ZERO` **on** | `pong_optimized.fragment` |
| **B — performance** | all three **off**, matching arter97 exactly | `+ pong_performance_overlay.fragment` |
| **C — mglru-switch** | A + runtime MGLRU kill switch | `+ 0001-mm-mglru-restore-upstream-kill-switch.patch` |

Both A and B keep CPU mitigations on, CFI and KASAN off, O2, ThinLTO. Variant A was
chosen originally on a safety bias that was never asked for; B is the
internally consistent "fastest thing that boots". Build B with:

```sh
scripts/kconfig/merge_config.sh -m .config \
    ../cfg/patches/kernel-optimized/pong_optimized.fragment \
    ../cfg/patches/kernel-optimized/pong_performance_overlay.fragment
```

Build C by applying the patch first:

```sh
git am < ../cfg/patches/kernel-optimized/0001-mm-mglru-restore-upstream-kill-switch.patch
# then build as A
```

## Hardware status

**Variant A boots and runs** — flashed on LineageOS (not the Nothing OS 4.1
it was stamped for; anti-rollback only requires the stamp be >= the device's,
so `os 16.0.0 / SPL 2026-06` passes there too). That settles the main open
risk: a 5.10.251 arter97-derived kernel works against this device's vendor
blobs.

## Built artifact

A verified build is published as a release:
<https://github.com/Omargamal7/notmuch2/releases/tag/pong-optimized-r45b2-nos41>
(`sha256 8fa6adca90ad799fa976a69708a6fa7244f17554316ecc5840eff466503bd9d5`).
Never booted on hardware — `fastboot boot` it, don't flash.

## Patches and Built-ins

The `0001-mm-mglru-restore-upstream-kill-switch.patch` restores the upstream v6.1 MGLRU toggle so that it can be tested at runtime.

An earlier revision shipped a patch removing a dangling `EXPORT_SYMBOL_GPL(map_kernel_range)`. It was only needed because that revision wrongly forced `CONFIG_MODULES=y`. This tree correctly uses `LAZY_INITCALL=y` which means `=m` symbols (like the Adreno GPU driver) are actually built-in, avoiding compilation errors and missing firmware issues (like focaltech_touch and qcacld). Under `LAZY_INITCALL=y`, `EXPORT_SYMBOL*` is a no-op and the stale export is harmless.
