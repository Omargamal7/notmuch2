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
| QCOM power stack (built-in) | already in arter97 r45b2 | free |
| DAMON | config flip (code is in ACK android12-5.10) | free |
| BBR default | config flip | free |
| PGO/BOLT/MLGO toolchain | WildKernels / Zixine build setup | build-side only |
| zram writeback off | arter97's 12 GB reasoning | free |

## Build

```sh
# 1. base tree
git clone <arter97 pong r45b2 tree> && cd <tree>

# 2. toolchain — the AOSP clang that carries +pgo +bolt +lto +mlgo
#    (the exact one in WildKernels-KSUNext-SUSFS-Pong's banner: clang 21)
#    from android.googlesource.com/platform/prebuilts/clang/host/linux-x86

# 3. merge the fragment
scripts/kconfig/merge_config.sh -m arch/arm64/configs/<base>_defconfig \
    patches/kernel-optimized/pong_optimized.fragment
make O=out olddefconfig

# 4. verify the merge actually took — merge_config warns on conflicts but
#    vendor symbol names drift between trees, so check the ones that matter
for s in LRU_GEN DAMON SCHED_WALT QCOM_MEMLAT DEFAULT_BBR CPU_MITIGATIONS; do
  grep -E "^CONFIG_${s}[=_]" out/.config || echo "MISSING: $s"
done

make O=out -j$(nproc) Image
```

Build it on the GCE kernel-builder VM, not locally.

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
