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
| QCOM stack (`SCHED_WALT`, `QCOM_MEMLAT`, …) | stay `=m` ✅ (see below) |
| `KASAN_HW_TAGS` | **dropped** — needs `CONFIG_KASAN=y`, which arter97 disables |
| `LRU_GEN_ENABLED` | **does not exist** in this tree — removed from the fragment |
| `LTO_CLANG_THIN` / `CFI_CLANG` | degrade to `LTO_NONE` **only under the wrong clang** — see below |

### The LTO false alarm

Expanding with the container's Ubuntu clang 18 yields `CONFIG_LTO_NONE=y`.
The **base defconfig alone does the same**, so this is a compiler-capability
gate, not a fragment defect. On the build VM with ClangBuiltLinux 22.1.0 it
should hold ThinLTO. Verify explicitly after configuring:

```sh
grep -E '^CONFIG_LTO' .config     # expect LTO_CLANG_THIN=y
```

If it says `LTO_NONE`, the toolchain is wrong — stop and fix that before
building, because CFI silently follows LTO down.

### Why the QCOM symbols stay `=m`

An earlier revision forced them to `=y`. The merge log showed that overriding
**ten vendor symbols at once**. arter97 keeps them modular; building vendor
drivers into the Image while `vendor_dlkm` still provides the matching `.ko`
is a route to duplicate driver init. They are now asserted at `=m` purely as
a tripwire — a rebase that changes them produces a visible "redefined"
warning.

## Build gotchas in his tree

- `Makefile:401` has `override LLVM_PATH := /home/arter97/android/nathan/...`.
  `override` beats command-line assignment, so you cannot set `LLVM_PATH=`.
  Either patch that line or override the consumers directly:
  `make LD=ld.lld CC=clang HOSTCC=gcc …`
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

## Residual risk

- Stock 4.1 `vendor_dlkm` modules are built against 5.10.237; arter97's kernel
  is 5.10.251. Same KMI generation, so this should work — but it is the single
  most likely failure mode, and it shows up as modules failing to load
  (no display, no modem, no wifi). Check `dmesg | grep -i "module\|kmi"` on the
  first `fastboot boot`.
- His config sets `CONFIG_LOCALVERSION="-arter97-'$(cat version)'"` with
  `LOCALVERSION_AUTO=y`. Module vermagic derives from the release string; if
  vendor modules refuse to load, this is the first thing to look at.
- `fastboot boot` first, never flash. Nothing here has been booted on a device.
