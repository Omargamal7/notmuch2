# Running the arter97 base on Nothing OS 4.1

arter97's tree targets Nothing OS 4.0. This is what changes when the target
is 4.1 (`Pong_B4.1-260618-1026`, the build pinned in `VERSION`).

## The good news: same KMI generation

| | arter97 r45b2 | NothingOS 4.1 stock |
|---|---|---|
| Kernel | 5.10.251 | 5.10.237 |
| ACK branch | `android12-5.10` | `android12-5.10` |
| Android | 12.0.0 (stamped) | 16 |

Both sit on **`android12-5.10`**, so the KMI generation matches and stock
`vendor_dlkm` modules are expected to load against his kernel. This is the
entire GKI contract and it is the reason this is worth attempting at all.
Note the Android *userspace* is 16 while the kernel branch is `android12` —
that's normal for this device and not a mismatch.

## The concrete blocker: boot header metadata

`build_kernel.sh` hardcodes:

```sh
export OS="12.0.0"
export SPL="2023-08"
```

These are stamped into the boot header as `os_version` / `os_patch_level`.
Nothing OS 4.1 reports security patch **2026-06-01** (verified from the stock
`boot.img` header). Flashing an image that declares `2023-08` on a device
provisioned at `2026-06` risks tripping **anti-rollback / AVB**.

**Fix before building:**

```sh
export OS="16.0.0"
export SPL="2026-06"
```

The stock 4.1 values to match are in `VERSION` (`security_patch=2026-06-01`)
and can be re-read any time with:

```sh
python3 scripts/kernel-survey/inspect_cmdline.py firmware/extracted/boot.img
```

## Merge behaviour — measured, not guessed

The fragment was test-merged against the real root `defconfig` and expanded
with `olddefconfig`. Results:

| Symbol | Outcome |
|---|---|
| `LRU_GEN`, `DAMON` (+PADDR/RECLAIM) | survive ✅ |
| `SHADOW_CALL_STACK`, `HARDENED_USERCOPY`, `INIT_STACK_ALL_ZERO` | survive ✅ |
| `DEFAULT_TCP_CONG="bbr"`, `ZRAM`, `CPU_MITIGATIONS`, `HZ_250` | survive ✅ |
| QCOM stack (`SCHED_WALT`, `QCOM_MEMLAT`, …) | forced `=y` — see "Verified on the build VM" |
| `KASAN_HW_TAGS` | **dropped** — needs `CONFIG_KASAN=y`, which arter97 disables |
| `LRU_GEN_ENABLED` | **does not exist** in this tree — removed from the fragment |
| `LTO_CLANG_THIN` / `CFI_CLANG` | degrade to `LTO_NONE` unless the full LLVM toolset is passed |

## Build gotchas in his tree

- `Makefile:401` has `override LLVM_PATH := /home/arter97/android/nathan/...`.
  `override` beats command-line assignment, so you cannot set `LLVM_PATH=`.
  Either patch that line or override the consumers directly:
  `make CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm … LLVM_IAS=1` (full toolset —
  see the LTO note below; do NOT pass `LLVM=1`, it re-enables that path)
- `build_kernel.sh` copies the **root-level** `defconfig`, not
  `arch/arm64/configs/defconfig`. The latter expands to a generic config with
  no MGLRU, WALT or zram and is not what built r45b2. Merge against the root
  file.
- The build needs `ccache` on PATH.

## MGLRU is off at boot

There is no `CONFIG_LRU_GEN_ENABLED` in this tree, so MGLRU is compiled in
but inactive. After booting:

```sh
adb shell 'echo y > /sys/kernel/mm/lru_gen/enabled'
adb shell cat /sys/kernel/mm/lru_gen/enabled
```

Make it persistent from userspace once it is proven stable.

## Verified on the build VM

Steps 1-5 were run on `max-perf-kernel-builder`. Three real blockers were
found and fixed; all are now handled by the fragment:

1. **LTO silently disabled.** `HAS_LTO_CLANG` needs `AS_IS_LLVM` + `llvm-nm` +
   `llvm-ar`. Passing only `CC`/`LD` fails the gate and yields
   `CONFIG_LTO_NONE=y`, taking CFI with it. Not a clang-version issue —
   Debian clang 19.1.7 works with the full toolset and `LLVM_IAS=1`. The
   earlier guess that this needed clang 22 was wrong.
2. **`LAZY_INITCALL` kills module support.** `menuconfig MODULES` has
   `depends on !LAZY_INITCALL`, so arter97's `CONFIG_LAZY_INITCALL=y` disables
   modules entirely, leaving 328 inert `=m` lines — including `QCOM_KGSL`,
   the GPU driver. Building from his committed defconfig as-is yields a
   kernel with no GPU driver and no vendor stack.
3. **Dependency chains.** `QCOM_MEMLAT` needs `QCOM_DCVS` + `QCOM_PMU_LIB`;
   the GPU governors need `QCOM_KGSL`. Forcing a leaf without its parents
   leaves it `=m`.

With the fragment applied and `LAZY_INITCALL` off: every vendor symbol
resolves to `=y`, `LTO_CLANG_THIN=y`, `LRU_GEN=y`, `DAMON=y`, and **0 stale
`=m` symbols remain**.

## Residual risk

- **The committed defconfig does not reproduce the shipped r45b2.** His
  binary contains WALT/memlat/GPU code that a build from his own defconfig
  would omit. Whatever config he ships from is not in the public tree, so
  this build is "arter97's source, our config" — not a rebuild of r45b2.
- Because module support is restored here, stock 4.1 `vendor_dlkm` modules
  may now load *alongside* built-in drivers. Watch for duplicate driver init
  on the first boot: `dmesg | grep -iE "already registered|duplicate|failed"`.
- `CONFIG_QCOM_KGSL=y` builds the Adreno driver in. If the 4.1 `vendor_dlkm`
  also provides `msm_kgsl.ko`, the built-in one wins and the module should
  fail to load harmlessly — but that is unverified on hardware.
- His config sets `CONFIG_LOCALVERSION="-arter97-'$(cat version)'"` with
  `LOCALVERSION_AUTO=y`. Module vermagic derives from the release string; if
  vendor modules refuse to load, this is the first thing to look at.
- `fastboot boot` first, never flash. Nothing here has been booted on a device.
