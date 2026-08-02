# notmuch2 — project state

Custom kernel work for **Pong** (Nothing Phone (2), `spike0en`, sm8475).
This file exists so a fresh session picks up without re-deriving everything.

## Layout

- `main` — firmware baseline: `VERSION` (pinned `Pong_B4.1-260618-1026`),
  `scripts/` fetch+extract pipeline, `device/checksums/`
- `kernel-optimized` — **the active branch.** Config fragments, the MGLRU
  patch, build docs. Read `patches/kernel-optimized/BUILD.md` and
  `NOTHINGOS-4.1-TARGET.md` first.
- `device/kernels/README.md` — survey of 17 Pong kernels, done from binaries

## Where things are

- Built images: <https://github.com/Omargamal7/notmuch2/releases/tag/pong-optimized-r45b2-nos41>
- Build VM: GCE `max-perf-kernel-builder` (project `crack-map-459722-u6`,
  zone `europe-west4-a`). **Keep it stopped when idle** — it bills while running.
- Build tree lives on that VM's 200 GB disk at `/mnt/build/pong/`. An fstab
  entry now mounts it automatically; device letters shuffle across reboots, so
  mount by UUID (`a88c9889-277c-4fe5-a17b-4a21ea713f36`), never by `/dev/sdX`.

## The three variants

Base is arter97 r45b2 (`5.10.251`) + our config. All share: MGLRU, DAMON,
BBRv3, QCOM WALT/memlat/KGSL, ThinLTO, CPU mitigations **on**, CFI/KASAN off,
O2, HZ 250, zram writeback off, boot header stamped `16.0.0` / `2026-06`.

| | difference | hardware status |
|---|---|---|
| **A** `pong-optimized` | SCS + HARDENED_USERCOPY + INIT_STACK_ALL_ZERO **on** | flashed, ran fine |
| **B** `pong-perf` | those three off (matches arter97) | ran a full day, **reported running hot — unexplained** |
| **C** `pong-mglru-switch` | A + runtime MGLRU kill switch | boots; **the toggle itself is still unexercised** |

## Traps — each of these cost a failed build

1. **`LAZY_INITCALL` is the modules symbol.** `init/Kconfig` puts
   `option modules` on `menuconfig LAZY_INITCALL`, and `MODULES depends on
   !LAZY_INITCALL`. It builds a monolithic kernel where `=m` means "built in,
   initcall deferred until userspace modprobes that name". arter97's 328 `=m`
   symbols are **not** stale. Forcing `CONFIG_MODULES=y` promotes all 328 to
   immediate built-in and breaks `qcacld-3.0` and `focaltech_touch`. Leave it
   alone. It also means **KernelSU LKM mode cannot work** (no module loader) —
   use Magisk, or build from arter97's `kernelsu` branch.
2. **LTO needs the full LLVM toolset**, not just `CC`/`LD`. `HAS_LTO_CLANG`
   requires `AS_IS_LLVM` + `llvm-nm` + `llvm-ar`. Miss them and LTO silently
   becomes `LTO_NONE`, taking CFI with it. Debian clang 19.1.7 is fine.
   Do **not** pass `LLVM=1` — `Makefile:401` has `override LLVM_PATH :=`
   pointing at arter97's home directory.
3. **Merge against the ROOT `defconfig`**, not `arch/arm64/configs/defconfig`.
   They are different files; the latter has no MGLRU, WALT or zram.
4. **The tree does not build as published** — `focaltech_touch` needs firmware
   headers that were never committed. Copy them from another NP2 tree (there's
   one on the VM at `/home/Admin/pong-nos41-kernel-build/`).
5. **`pigz` must be installed** or the build dies with `Error 127`.
6. **Embedded configs lie.** arter97 and Meteoric both embed a stale
   5.10.185-era `.config` that does not match what built them. Always verify
   against the binary (`llvm-nm`, `strings`) or the source tree.

## Open questions

- **Why did B run hot?** Never diagnosed. Removing those three options should
  reduce work, not add heat. A full day of use rules out post-flash dexopt.
  Next step if it recurs: `top -n 1 -b -o %CPU,PID,ARGS | head -15` while it's
  happening. Watch for `kdamond` — `DAMON_RECLAIM` is in all three variants.
- **Does the MGLRU toggle work?** C boots, but `lru_gen_change_state()` only
  runs on a write to `/sys/kernel/mm/lru_gen/enabled`. Needs root. Rebuilds
  every LRU list on each flip.
- **Is MGLRU worth anything?** The whole point of C. Untested.
- **Toolchain**: we build with clang 19; arter97 uses ClangBuiltLinux 22, and
  PGO/BOLT/MLGO remains the largest untried lever.

## Identifying a running kernel

```sh
zcat /proc/config.gz | grep LRU_GEN        # CONFIG_LRU_GEN_ENABLED=y => variant C only
ls -l /sys/kernel/mm/lru_gen/enabled       # 0644 => C, 0444 => A or B
cat /proc/version                          # build timestamps differ per variant
```

## Conventions

- Commit straight to the working branch; no PRs (user's call).
- `fastboot boot` before `fastboot flash`, always — especially for C.
- Nothing here is benchmarked. Treat every claim as a hypothesis to measure.
