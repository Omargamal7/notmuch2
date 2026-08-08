# LineageOS vs Nothing OS 4.1 (Pong / Nothing Phone 2) — source-level diff

Scope: official `LineageOS/android_device_nothing_Pong` (branch `lineage-23.2`, current)
and its companion `LineageOS/android_kernel_nothing_sm8475`, compared against stock
**Nothing OS `Pong_B4.1-260618-1026`** — the exact build pinned in this repo's `VERSION`
file (Android 16, build ID `BQ2A.250721.001-BP2A.250605.031.A3`, security patch
2026-06-01).

## Method and honesty about what this is

I did **not** extract the stock Nothing OS 4.1 firmware in this session (the release
images are multi-GB and out of scope for a research pass; `firmware/` in this repo is
still empty/gitignored). Everything below is grounded in one of three ways, and each
claim below is tagged accordingly:

- **[SRC]** — read directly from LineageOS's own public source this session (device
  tree, kernel tree, vendor config — via `raw.githubusercontent.com`, not
  paraphrased from memory).
- **[EXTRACT-EVIDENCE]** — inferred about *stock* Nothing OS from artifacts LineageOS
  extracted from a real stock dump (`proprietary-files.txt` blob paths, the spoofed
  build fingerprint string). This is indirect but strong: those strings had to come
  from a real stock system dump to exist at all.
- **[EXTERNAL]** — community/journalism/official-doc sources found via search, cited
  individually with a confidence label. Several primary sites (`wiki.lineageos.org`,
  `lineageos.org`, `source.android.com`, `xdaforums.com`, `deepwiki.com`) were
  **blocked by this environment's egress proxy** for direct fetching; where that
  happened I relied on the search tool's own retrieval (noted per-claim) or on
  raw GitHub mirrors of the same content.
- **[REPO]** — already-established fact from *this* repo's `main`/`kernel-optimized`
  branches (not re-derived, per your instruction).

Where I could not clear this bar, I say so explicitly rather than filling the gap
with "what custom ROMs typically do."

One correction to flag in your own repo while I'm here: `VERSION`'s
`device_codename=spike0en` **[SRC]** is the GitHub handle of the firmware-archive
maintainer (`spike0en/nothing_archive`), not the device codename — the actual
codename, used throughout LineageOS's tree and Nothing's own build tags, is `Pong`
(model `A065`/`AIN065`). Doesn't affect anything downstream, just noting it since it's
adjacent to this research.

---

## 0. Baseline parity — verified

| | Stock Nothing OS (`Pong_B4.1-260618-1026`) | LineageOS (`lineage-23.2`) |
|---|---|---|
| Android version | 16 **[REPO]** | 16 **[SRC]** (`lineage-23.x` = Android 16) |
| Build ID | `BQ2A.250721.001-BP2A.250605.031.A3` **[REPO]** | Same string, literally **[SRC]** — see §4 |
| Device codename | `Pong`, model `A065`/`AIN065` **[EXTERNAL, LineageOS wiki data file]** | `PRODUCT_DEVICE := Pong`, `PRODUCT_MODEL := A065` **[SRC]** |
| Kernel branch lineage | `android12-5.10` KMI, 5.10.237 **[REPO, from `device/kernels/README.md`]** | `android12-5.10` KMI, 5.10.246 **[SRC]** |

The Android-version and build-ID match is not a coincidence: LineageOS deliberately
spoofs its fingerprint to this exact stock build for GMS/Play-certification purposes
(see §4). This is the strongest cross-check in this whole report — two independently
maintained data sources (your repo's `VERSION`, LineageOS's `lineage_Pong.mk`) agree
on a 40-character build ID string character-for-character.

---

## 1. AOSP-vs-OEM framework diffs

### 1.1 Launcher

LineageOS ships **`Launcher3QuickStep`** **[SRC, `vendor/lineage/config/common_mobile.mk`]**
— LineageOS's own fork of AOSP's Pixel-style Launcher3/QuickStep, not the old
"Trebuchet" branding (that name was retired). It's themed via LineageOS's
`ThemePicker`/`ThemesStub`/`LineageBlackTheme` packages **[SRC]**, not Nothing's dot-matrix
icon pack/folder styling. Nothing's own launcher (closed-source, dot-matrix grid,
NT-branded icon shapes) is absent entirely — there is no launcher entry pulled from
stock in `proprietary-files.txt` **[SRC]**.

### 1.2 Glyph Interface — reimplemented, not ported, and not at feature parity

This is the most concrete framework-level finding. LineageOS carries a **from-scratch,
open-source reimplementation** of the Glyph Interface as a privileged system app,
`org.lineageos.glyph` (module name `PongGlyph`), living in the device tree's `nt-glyph/`
directory **[SRC — read `Android.bp` and `AndroidManifest.xml` directly]**.

What it reimplements (from the manifest's declared services/tiles):
- Call-received flash (`CallReceiverService`)
- Charging-progress flash (`ChargingService`)
- Reverse-wireless-charging/Powershare indicator (`PowershareService`)
- Flip-phone-over-to-mute (`FlipToGlyphService`)
- Music visualizer (`MusicVisualizerService`)
- Volume-level indicator (`VolumeLevelService`)
- Notification flash (`NotificationService`, a `NotificationListenerService`)
- Two Quick Settings tiles (Glyph toggle, Torch) and a Settings page

What stock Nothing OS has that this **does not** reimplement, per Nothing's own
Glyph documentation and independent reviews **[EXTERNAL, moderate-confidence —
9to5Google's "ultimate guide," Android Authority, XDA, cross-checked across 3+
independent write-ups that agree]**: **Glyph Composer** (custom light+sound sequence
authoring, 5 sound packs), **Glyph Toys** (a small toy/widget ecosystem plus a public
"Glyph Developer Kit" SDK for third-party toy integration), and ride/delivery-service
progress-tracking integrations (Uber etc.) that depend on Nothing's own backend
partnerships. Phone (2) has **33 LED zones across 11 strips** (not the newer
"Glyph Matrix" display — that's Phone (3), different hardware) **[EXTERNAL, same
source set]**. None of the Composer/Toys/SDK/partner-integration layer appears
anywhere in the LineageOS device tree — it's not stripped-and-present, it's simply
never implemented. This tracks: those depend on Nothing's closed backend/marketplace,
not just LED-driver access.

The LED hardware itself is driven by an Awinic **AW20036** LED-matrix driver IC —
confirmed at the kernel-config level, see §3.

### 1.3 A boot-classpath compatibility shim for Nothing's proprietary framework

`nt-fwk.pong` is added to **`PRODUCT_BOOT_JARS`** **[SRC, `device.mk` lines 245-250]** —
i.e. LineageOS loads a module into the boot classpath itself, not just an app. Its
entire content (as of this branch) is one class, `com.nothing.NtFeaturesUtils`
**[SRC, read the full file]**, which reimplements Nothing's own proprietary
feature-flag bitset mechanism: it reads `ro.build.nothing.feature.base` plus
per-product/per-device diff properties as hex-encoded `BigInteger` bitmasks and
exposes `isSupport(int...)`. This exists because **vendor blobs Nothing ships**
(HALs/services that LineageOS *does* pull in — see §2) call into
`com.nothing.NtFeaturesUtils` at runtime and will fail to load without a class of
that exact name/package on the boot classpath. LineageOS chose to reimplement the
minimum surface rather than drop those blobs. This is a genuinely different strategy
from "debloat the OEM layer" — it's "keep the vendor HAL contract, replace the OEM
app/framework layer around it."

### 1.4 Nothing's own resource overlays are partially retained — as source, not binary

`device.mk`'s "Pong overlays" block **[SRC]** pulls in `NTCarrierConfigResTarget`,
`NTFrameworksResTarget`, `NTNfcResTarget`, `NTSettingsProviderResTarget`,
`NTSettingsResTarget`, `NTSystemUIResTarget`, `NTWifiResMainlineTarget`,
`NTWifiResTarget` — these are Nothing-prefixed (`NT`) RRO overlay packages generated
from source directories `overlay/pong`, `overlay/qssi`, `overlay/taro` that exist in
the device tree itself **[SRC, confirmed directory listing]**, not extracted binaries
(they don't appear in `proprietary-files.txt`). This is Qualcomm CAF's standard
per-OEM multi-target overlay build mechanism — LineageOS inherited the directory
structure/naming Nothing's own internal tree uses (`NT` = manufacturer prefix), and
compiles its own resource content into it. In parallel, LineageOS layers its **own**
separate `overlay-lineage/` directory on top (`DEVICE_PACKAGE_OVERLAYS`) for
Lineage-specific product config. Net effect: some Nothing-shaped RRO *plumbing*
survives (needed for the vendor/carrier-config contract), but the actual Nothing
visual identity (System UI look, Settings structure) does not — LineageOS supplies
its own resource values into those same overlay slots.

### 1.5 LineageOS-only framework additions absent from stock

- **LiveDisplay** (`vendor.lineage.livedisplay-service.nt.pong` **[SRC]**) — LineageOS's
  long-standing HAL-backed display color-temperature/night-mode/reading-mode
  subsystem. This has no Nothing equivalent in scope here (Nothing OS has its own,
  unverified, screen-comfort settings — not compared, flagged as such).
- **Lineage Health** charging-control service (`vendor.lineage.health-service.default`
  **[SRC]**), configured with `charging_control_charging_path =
  /sys/class/qcom-battery/scenario_fcc` and a threshold constant of `9000`
  **[SRC]** — a fast-charge-current-based charge-limit feature. Nothing OS ships its
  own battery-protection/charge-limit toggle **[EXTERNAL, general/unverified for this
  exact build]**; I did not compare the two mechanisms at the sysfs level.

---

## 2. Preinstalled app / package list diff

**Strongest evidence here is negative-space evidence**: `proprietary-files.txt`
**[SRC, fetched and grepped in full — 2093 lines]** is the literal list of binaries
LineageOS's build system pulls out of a real stock Pong dump to build the vendor
partition. Only **six app-shaped entries** exist in it:

```
vendor/app/CACertService/CACertService.apk
vendor/app/CneApp/CneApp.apk                          (Qualcomm Connectivity Engine)
system/priv-app/NothingAudioEffectService/...apk       (HW-tied audio effects service)
vendor/app/TimeService/TimeService.apk                 (QTI time service)
vendor/app/IWlanService/IWlanService.apk                (QTI IWLAN telephony service)
product/app/uimgbaservice/uimgbaservice.apk
```

Plus two Google-authored **hardware-enablement stubs**, not Google apps proper:
`HotwordEnrollmentOKGoogleHEXAGON`/`HotwordEnrollmentXGoogleHEXAGON`
(`product/priv-app/...`) — these just let the low-power DSP load a keyword-detection
model; they do nothing without an actual Assistant on top, and are commonly kept in
AOSP-based builds purely for hardware compatibility.

**Every consumer-facing Nothing app is simply absent, not overlaid**: no Nothing
Camera, no Nothing X, no Nothing Recorder, no Nothing Weather, no Essential Space, no
Dot Notes, no Nothing Community app. **[EXTRACT-EVIDENCE]** — confirmed by the
complete absence of `product/priv-app` or `system/priv-app` entries for any of them
in the real extracted-blob list; not an inference from "custom ROMs usually debloat."

LineageOS's own default app set, read directly from `vendor/lineage/config/*.mk`
**[SRC]**:

| Category | Package(s) |
|---|---|
| Launcher | `Launcher3QuickStep`, `Launcher3Overlay` |
| Camera | `Aperture` (unless `PRODUCT_NO_CAMERA`) |
| Gallery | `Camelot`, `Glimpse` |
| Calendar | `Etar` |
| Music | `Twelve` |
| Recorder | `Recorder` (LineageOS's own, not Nothing's) |
| Backup | `Seedvault` |
| Keyboard | `LatinIME` |
| Equalizer | `AudioFX` |
| Theming | `ThemePicker`, `ThemesStub`, `LineageBlackTheme` |
| Telephony | `messaging`, `Stk`, `apns-conf.xml`, `sensitive_pn.xml` |
| Misc | `AvatarPicker`, `Backgrounds`, `QuickAccessWallet`, `Profiles` |
| Glyph | `PongGlyph` (`org.lineageos.glyph` — see §1.2) |

**Google apps**: neither side bundles GMS unconditionally in the *build config* I
read — LineageOS gates it behind `WITH_GMS`/`WITH_GMS_COMMS_SUITE` **[SRC,
`telephony.mk`]**, i.e. off unless a builder opts in (official LineageOS downloads
ship with no Google apps; users add MindTheGapps or similar separately —
**[EXTERNAL, well-established LineageOS project policy, not re-verified against a
primary doc this session since `lineageos.org` was unreachable from here]**). Stock
Nothing OS ships GMS preinstalled as a normal condition of being a
Play-certified retail device — **[EXTERNAL/general, not verified against this
specific firmware image]**.

---

## 3. Kernel/vendor differences beyond the `kernel-optimized` branch's arter97 work

Per your instruction I read `device/kernels/README.md` and
`patches/kernel-optimized/{BUILD.md,NOTHINGOS-4.1-TARGET.md}` on `kernel-optimized`
first — that survey already establishes, from binaries: stock kernel is 5.10.237, no
MGLRU/DAMON/BBR, QCOM power stack as modules, Android clang 12, no CPU-mitigation
stripping anywhere in the 17-kernel survey, and arter97 r45b2 (the base you're
building from) is the only one with MGLRU and is also the only one that *strips*
CFI_CLANG/SHADOW_CALL_STACK/HARDENED_USERCOPY/KASAN. I have not re-derived any of
that. What follows is new: **where LineageOS's own kernel sits relative to both.**

LineageOS does not reuse arter97's tree, and does not reuse a third-party "optimized"
kernel at all — it maintains its own official fork,
`LineageOS/android_kernel_nothing_sm8475` **[SRC]**:

| | Stock (per `kernel-optimized` survey) | arter97 r45b2 (your base) | **LineageOS official** |
|---|---|---|---|
| Version | 5.10.237 | 5.10.251 | **5.10.246** **[SRC, `Makefile`]** |
| Build style | vendor GKI-config kernel | monolithic, non-GKI, `LAZY_INITCALL` | **GKI**: `TARGET_KERNEL_CONFIG := gki_defconfig vendor/waipio_GKI.config vendor/nothing/waipio_GKI.config vendor/debugfs.config` **[SRC, `BoardConfig.mk`]** |
| MGLRU (`LRU_GEN`) | no | **yes** (only one in the 17-kernel survey) | **no** — absent from `gki_defconfig` and both fragments **[SRC, grepped all three files]** |
| DAMON | no | no | **yes** — `CONFIG_DAMON=y`, `DAMON_PADDR=y`, `DAMON_RECLAIM=y` in base `gki_defconfig` **[SRC]** |
| Hardening (CFI/SCS/HARDENED_USERCOPY/KASAN) | not independently checked this session | **stripped** (per `kernel-optimized` finding) | **kept**: `CFI_CLANG=y`, `SHADOW_CALL_STACK=y`, `HARDENED_USERCOPY=y`, `KASAN=y`, `KASAN_HW_TAGS=y` all present, untouched, in `gki_defconfig` **[SRC]** — whether `KASAN_HW_TAGS` does anything depends on MTE hardware support on this SoC, which I did not verify |
| Toolchain | Android clang 12 | ClangBuiltLinux 22.1.0 | not verified this session |
| History | — | — | full upstream git history preserved (~1.04M commits on the branch), same CAF/ACK ancestry as the others **[SRC]** |

The Nothing-specific config fragment LineageOS builds against,
`vendor/nothing/waipio_GKI.config` **[SRC, fetched in full]**, is very likely the same
fragment Nothing's own build uses — it's the real hardware-enablement layer:
`CONFIG_GOODIX_FINGERPRINT`, `CONFIG_TOUCHSCREEN_GOODIX_BRL_SPI`,
`CONFIG_AWINIC_HAPTIC_HV`, **`CONFIG_LEDS_AW20036`** (the Glyph LED driver IC),
`CONFIG_NT2_HWID`, `CONFIG_NOTHING_BOOTLOADER_LOG`, `CONFIG_NOTHING_SECURE_ELEMENT`,
`CONFIG_NT_SECURE_STATE`, `CONFIG_NT_SLOT_STATE`, `CONFIG_NOTHING_RESTART_HANDLER`,
`CONFIG_ZRAM_WRITEBACK=y` (left **on**, vs. the "disabled on 12GB devices" tuning the
`kernel-optimized` survey found on some third-party kernels). The out-of-tree module
set (`TARGET_KERNEL_EXT_MODULES`: `qcom/opensource/{audio,camera,cvp,eva,video}-kernel`,
`mmrm-driver`, `dataipa`, `datarmnet*`, `qcacld-3.0`) **[SRC]** mirrors the standard CAF
vendor-module split — LineageOS isn't restructuring the module boundary Nothing uses,
just rebuilding the same pieces from source with ACK's newer point release and
security backports.

**Net read**: your `kernel-optimized` project (arter97 base) and official LineageOS
are solving different problems with the same upstream ancestry. arter97 trades
hardening for MGLRU + a newer point release, built as a monolithic non-GKI kernel.
LineageOS stays GKI-compliant, keeps every ACK hardening default, picks up DAMON (not
MGLRU), and its main advantage over stock is a newer kernel sublevel (.246 vs .237)
riding ACK's ongoing security/backport stream rather than any perf-tuning intent.
Neither arter97 nor LineageOS is "better" in a vacuum — they're optimizing for
different things (perf-with-reduced-hardening vs GKI-compliant-with-security-patches).

---

## 4. Build-flag / config / security-model differences

### 4.1 Fingerprint spoofing — verified against your own repo

`lineage_Pong.mk` **[SRC]** sets:
```
BuildDesc="qssi-user 16 BQ2A.250721.001-BP2A.250605.031.A3 2512261110 release-keys"
BuildFingerprint=Nothing/Pong/Pong:12/SKQ1.250415.001/2512261110:user/release-keys
```
The build-ID substring (`BQ2A.250721.001-BP2A.250605.031.A3`) is **character-for-character
identical** to this repo's own pinned `VERSION.build_id` for `Pong_B4.1-260618-1026`
**[REPO + SRC cross-check]**. This tells you two things directly: (1) stock ships as
`user`/`release-keys` (that string only makes sense if it's copied from a real stock
build), and (2) LineageOS is deliberately impersonating this exact build's identity
for Google's device-certification/Play-Integrity matching, not a generic placeholder.
Note the fingerprint's own `12` (API level slot) looks stale/inconsistent with
`BuildDesc`'s `16` — a quirk of the spoof string, not something I can resolve further
without the real stock `build.prop`.

### 4.2 Verified boot / AVB

`BoardConfig.mk` **[SRC]**: `BOARD_AVB_ENABLE := true`, with a full vbmeta chain
(`vbmeta`, `vbmeta_system` over product/system/system_ext, `vbmeta_vendor` over
odm/vendor/vendor_dlkm) — but signed with the **well-known AOSP test keys**
(`external/avb/test/data/testkey_rsa4096.pem` / `testkey_rsa2048.pem`), not an OEM
production key. That vbmeta cannot chain to Nothing's locked-bootloader root of
trust, which is exactly why an unlocked bootloader is required to run it at all.

Per AOSP's own device-state model **[EXTERNAL — retrieved via search since
`source.android.com` was directly unreachable from this environment; content is
consistent with well-established, stable AOSP documentation]**: LOCKED devices only
boot images chaining to the burned-in root of trust; UNLOCKED devices show an
ORANGE warning screen (dismissed after ~10s) and boot regardless of signature.
A device can alternatively be re-locked against a **user-enrolled** custom AVB key
(`fastboot flash avb_custom_key`), which shows YELLOW instead of ORANGE and restores
enforcement against that user key.

**Whether Nothing Phone (2)'s bootloader specifically supports the
`avb_custom_key` re-lock flow is something I could not verify** — search results were
inconsistent/low-quality on this specific device (one source conflated it with an
unrelated MediaTek-device unlock-warning note, which I've discarded rather than
report as fact). Treat Nothing Phone 2 custom-AVB-key relocking as **UNVERIFIED**,
not confirmed either way. What I can confirm from LineageOS's own config: LineageOS
builds *do* produce a full AVB chain (so a custom-key relock, if the bootloader
supports it, has something valid to point at) — it's not shipping with AVB simply
turned off.

Bootloader unlock itself: Nothing phones reportedly use a standard, offline
`fastboot flashing unlock` with no account/waiting-period gate, comparable to Pixel
**[EXTERNAL, moderate confidence — consistent across the sources found, but I
couldn't reach Nothing's own official unlock documentation directly to confirm the
exact data-wipe/warranty language]**.

### 4.3 SELinux

No `androidboot.selinux=permissive` or equivalent override exists anywhere in the
device tree files I read (`BoardConfig.mk`, `device.mk`, `sepolicy/vendor/file_contexts`)
**[SRC]** — AOSP defaults to Enforcing absent an explicit override. LineageOS's own
engineering documentation **[EXTERNAL, `raw.githubusercontent.com/LineageOS/www` —
the canonical source repo for `lineageos.org`, fetched directly, dated 2025-02-25]**
states SELinux Enforcing has been a CTS/GMS requirement since Android 5.0, which both
a Play-certified stock build and a CTS-targeting LineageOS build are built to satisfy.
I did **not** obtain a live `getenforce` from either build — this is **MEDIUM
confidence by absence-of-override plus policy statement, not a direct read.**

### 4.4 Signing keys

Stock: `release-keys` per the spoofed-fingerprint string (§4.1) — a normal retail
`user`/`release-keys` build, as expected for anything shipping GMS. LineageOS
official builds are also tagged `release-keys`, signed with LineageOS's own build
infrastructure key (not the public AOSP test key used for the *AVB* vbmeta blobs in
§4.2 — those are two separate signing mechanisms: APK/OTA signing vs AVB boot-chain
signing) **[EXTERNAL/general LineageOS project policy — not re-verified against a
live artifact this session]**.

---

## What I verified vs. what I'm reporting from elsewhere — summary

**Directly verified from primary source this session (`[SRC]`)**: LineageOS device
tree structure and full content of `lineage_Pong.mk`, `device.mk`, relevant parts of
`BoardConfig.mk`, `sepolicy/vendor/file_contexts`, `proprietary-files.txt` (all 2093
lines), `nt-glyph/{Android.bp,AndroidManifest.xml}`, `nt-fwk/.../NtFeaturesUtils.java`,
the kernel tree's `Makefile` and all three GKI config fragments, and LineageOS's
generic `vendor/lineage` app/config makefiles. This is real source, fetched and
grepped, not paraphrased from training data.

**Indirect but strong (`[EXTRACT-EVIDENCE]`)**: everything about *stock* Nothing OS's
app/blob inventory, derived from what LineageOS's own extraction tooling lists as
pulled from a real dump (and, by omission, what it doesn't pull).

**External, cited and confidence-labeled (`[EXTERNAL]`)**: Glyph feature-set
comparison (Composer/Toys/SDK), bootloader-unlock behavior, GMS-bundling norms,
AVB device-state semantics. Multiple primary docs (`wiki.lineageos.org`,
`lineageos.org`, `source.android.com`, `xdaforums.com`, `deepwiki.com`) were
unreachable directly from this environment (egress-proxy blocked); where that
mattered I said so per-claim rather than silently substituting a lower-quality
source.

**Not attempted**: extracting and diffing the actual stock Nothing OS 4.1 `system`/
`product` images (multi-GB, out of scope for a research pass) — so no claim in this
report about stock `build.prop` values, stock SELinux policy content, or the stock
preinstalled-app manifest is a direct read of that firmware. Those claims rest on
§2's extraction evidence and external sourcing instead, as flagged.

## Open questions / what could not be verified

- Whether Nothing Phone (2)'s bootloader supports `avb_custom_key` re-locking
  (removes the ORANGE warning state) — genuinely unresolved, not just unconfident.
- Exact stock `build.prop` contents (`ro.build.type`, `ro.debuggable`, full
  `ro.build.*` set) for `Pong_B4.1-260618-1026` specifically — inferred only from the
  spoofed-fingerprint string, not read directly.
- Whether `CONFIG_KASAN_HW_TAGS` is functionally active on SM8475's Kryo cores (MTE
  hardware support not independently confirmed) or just a config bit with no runtime
  effect.
- LineageOS official-build signing-key policy (own key vs AOSP test-key) — reported
  as established project policy, not re-verified against a live signed artifact.
- Whether Nothing OS 4.1's own screen-comfort/night-mode and battery-charge-limit
  features differ meaningfully from LiveDisplay/Lineage Health at a mechanism level —
  not compared.
- Exact changelog delta of the specific incremental build `Pong_B4.1-260618-1026`
  itself (vs. the general 4.1-branch feature set reported by tech press) — per this
  repo's own `device/updates.md`, this incremental was never published with public
  release notes.
