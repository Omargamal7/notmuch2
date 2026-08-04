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

## Verified on the build VM — built successfully

Built end-to-end on `max-perf-kernel-builder`. `BUILD_RC=0`, `Image.gz`
18.2 MB, `boot.img` 19.8 MB, header v4, `os_version=16.0.0`,
`security_patch=2026-06`. Published as a release (see BUILD.md).

Feature counts in the finished kernel, vs the reference builds:

| | arter97 r45b2 | Meteoric | this build |
|---|---|---|---|
| `lru_gen` (MGLRU) | 3 | 0 | **3** |
| `damon` | 0 | 25 | **25** |
| `memlat` | 45 | 45 | **45** |
| `waltgov` | 5 | 5 | **5** |

Four things had to be understood to get there:

1. **LTO needs the full LLVM toolset.** `HAS_LTO_CLANG` requires `AS_IS_LLVM`
   plus `llvm-nm` and `llvm-ar`. Passing only `CC`/`LD` fails the gate and
   silently yields `CONFIG_LTO_NONE=y`, taking CFI with it. Not a
   clang-version issue — Debian clang 19.1.7 works with the whole toolset and
   `LLVM_IAS=1`.
2. **`LAZY_INITCALL` is the modules symbol.** `init/Kconfig` puts
   `option modules` on `menuconfig LAZY_INITCALL`, and
   `MODULES depends on !LAZY_INITCALL` — they are mutually exclusive. It
   builds a monolithic kernel where `=m` means "compiled in, initcall
   deferred until userspace modprobes that name". So arter97's 328 `=m`
   symbols are **not** stale: `CONFIG_QCOM_KGSL=m` means the Adreno driver is
   present. Forcing `CONFIG_MODULES=y` strips `option modules`, promotes all
   328 to immediate built-in, and breaks the build — `qcacld-3.0`'s Kbuild is
   not written for `built-in.a`, and `focaltech_touch` then fails too. Leave
   `LAZY_INITCALL=y` alone.
3. **The tree does not build as published.** `focaltech_touch` needs
   `include/firmware/FT3680_..._app.i`, referenced by `focaltech_config.h` and
   required by `CONFIG_TOUCHSCREEN_FTS=m` in his own defconfig, but never
   committed and not gitignored. Sourced from a separate NP2 tree.
4. **`pigz` is required** — his Makefile uses parallel gzip for
   `kernel/config_data.gz`; without it the build dies with `Error 127`.

## Residual risk

- **The committed defconfig does not reproduce the shipped r45b2.** Whatever
  config he ships from is not public, so this is "arter97's source, our
  config" — not a rebuild of r45b2.
- **Never booted.** No hardware validation whatsoever. `fastboot boot` only.
- Kernel is 5.10.251 against 4.1's 5.10.237 vendor blobs. Same
  `android12-5.10` KMI generation so it should hold, but this is the most
  likely failure and shows up as no display/modem/wifi. First check on boot:
  `dmesg | grep -iE "module|kmi|vermagic|failed"`.
- MGLRU is compiled in but **off at boot** (no `CONFIG_LRU_GEN_ENABLED` in
  this tree). Enable via sysfs, make persistent only once proven stable.
- The build lives on the VM's `/dev/sdb`, which has **no fstab entry** and
  silently unmounted once mid-session. Remount with `mount /dev/sdb /mnt/build`.
