# Pong kernel survey — verified feature inventory

Empirical comparison of 17 kernels for Pong (Nothing Phone (2)), done to
find what actually differs on **performance and power**, and what a better
kernel would combine.

## Method, and one important caveat

Every claim below comes from the **kernel binary** (`Image` / `boot.img`),
not from the embedded `IKCONFIG`.

> **The embedded config lies on some kernels.** arter97 and Meteoric both
> embed a `.config` whose header reads `Linux/arm64 5.10.185` while the
> kernels are 5.10.251 and 5.10.237 respectively. Only one `IKCFG` blob
> exists in each image, so this isn't an extraction error — it's a stale
> checked-in defconfig embedded verbatim.
>
> Consequences, both verified:
> - Their embedded configs are **byte-identical** (`a8b21ecc…`). This has
>   been read as "Meteoric is arter97 rebranded". It isn't — it only means
>   they share a defconfig ancestor.
> - arter97's embedded config claims `CONFIG_DAMON=y`; the binary contains
>   **zero** DAMON symbols. The config is simply not what built it.
>
> Stock (`5.10.237`/`5.10.237`) and the GKI-derived kernels
> (`5.10.246`/`5.10.246-gki`) *do* have matching headers, so their configs
> are trustworthy. Verify against binaries before trusting any config-based
> comparison of these kernels.

## Feature inventory

| Kernel | Version | QCOM power stack | MGLRU | DAMON | BBR | Toolchain |
|---|---|---|---|---|---|---|
| **arter97 r45b2** | 5.10.251 | **built-in** | **yes** | no | yes | ClangBuiltLinux 22.1.0 |
| Meteoric V6 | 5.10.237 | built-in | no | yes | yes | Neutron clang 19 |
| Ryuusei | 5.10.248 | built-in | no | yes | yes | Ubuntu clang 18.1.3 |
| LineageOS-ReSukiSU | 5.10.246-gki | modules (`=m`) | no | yes | no (cubic only) | Ubuntu clang 18.1.3 |
| WildKernels-KSUNext | 5.10.246-gki | modules | no | yes | yes | **Android clang 21 +pgo +bolt +lto +mlgo** |
| Wild 5.10.260-a13 | 5.10.260 | modules | **yes** | yes | yes | Android clang 14 |
| Zixine-Elysium | 5.10.251 | modules | no | yes | **bbr only, cubic removed**; `HZ=300` | Android clang 18 +pgo +bolt +lto +mlgo |
| Stock NothingOS | 5.10.237 | modules | no | no | no | Android clang 12 |

"QCOM power stack" = `SCHED_WALT` + `QCOM_MEMLAT` + `CPU_IDLE_GOV_QCOM_LPM`
+ `DEVFREQ_GOV_QCOM_ADRENO_TZ` + `GPUBW_MON` + `QTI_THERMAL_LIMITS_DCVS`.
Built-in on the CLO-derived trees, shipped as vendor_dlkm modules on the
GKI-derived ones — functionally present either way, different packaging.

## Findings that matter

1. **arter97 r45b2 is the only kernel with the QCOM power stack built in
   *and* MGLRU.** That combination exists nowhere else in the survey, which
   makes it the natural base for an optimized build.
2. **Nobody disables CPU mitigations.** `CONFIG_CPU_MITIGATIONS=y` wherever
   the symbol exists; absent only on the stale 5.10.185-era defconfigs,
   where it defaults to `y` anyway. No `anykernel.sh` in 14 packages patches
   the cmdline, and every `boot.img` cmdline field is empty. The
   "custom kernels turn off mitigations for speed" belief is false here.
3. **Nobody uses `-O3`, and nobody strips hardening** — CFI, shadow call
   stack, `KASAN_HW_TAGS` (MTE, boot-gated so near-free), UCLAMP and
   ENERGY_MODEL are on everywhere.
4. **The largest untapped lever is the toolchain.** PGO + BOLT + MLGO
   (WildKernels' Android clang 21, Zixine's clang 18) is real, measurable
   optimization and is invisible to any config diff — it shows up only in
   the banner string.
5. Genuine deliberate tuning found: BBR as default (Wild, Zixine), `HZ=300`
   (Zixine only, unbenchmarked), ThinLTO vs FullLTO, zram writeback
   disabled on 12 GB devices.

## Reproducing

`scripts/kernel-survey/` holds the extraction tooling:
`kscan.py` (banner + `IKCONFIG` from `Image`/`boot.img`, handles gzip and
the `IKCFG_ST`-in-code false match) and `inspect_cmdline.py` (boot header
v0–v4 and vendor_boot cmdline + bootconfig).
