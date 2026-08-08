# Customization plan — from the LineageOS diff research to branches

Companion to `CUSTOMIZATION.md`'s workflow and
[`lineageos-vs-nothingos-4.1-pong.md`](./lineageos-vs-nothingos-4.1-pong.md) (the
source-level diff research this plan is built on — read that first for the
evidence behind any claim below; this file only summarizes what's actionable).

## Current state (verified against `origin` at time of writing)

| Branch | Status | Concern |
|---|---|---|
| `main` | stock baseline | — |
| `claude/notmuch2-repo-structure-28boi4` (PR #2, open) | fixes boot/vendor_boot ramdisk tooling | real `unpack_bootimg`/`mkbootimg` pipeline; found stock ships boot header v4 — `boot.img`'s ramdisk is generic GKI, the real device ramdisk (fstab, avb keys, modules) is in `vendor_boot.img` |
| `adb-root` | built on top of PR #2's branch (not yet reachable from `main`) | proof of concept: overlays `force_debuggable` into `vendor_boot.img`'s ramdisk |
| `kernel-optimized` | separate track, unaffected by this doc | arter97 r45b2 + MGLRU/DAMON/BBR fragment + hardening toggles |
| `kernel-clean` (agreed, not yet pushed) | separate track, unaffected by this doc | arter97 `master`, no fragment, boot-stamp fix only |

Two things worth a look, found while checking this, not acted on here since
they're outside this branch's scope:

- `kernel-optimized`'s tip commit (`5a956f5`, message: *"Add debloat scripts,
  AOSP EROFS fixes, and OrangeFox recovery integration"*) doesn't actually
  contain any of those three things — the tree at that commit has only kernel
  patches/docs and the standard `scripts/`. The commit message looks
  stale/misattributed. Worth checking before building further on top of it.
- `kernel-optimized` also carries a stray top-level file named `notmuch2`
  that's a gitlink pointing at this same repo's own `main` HEAD — looks like
  an accidental nested-clone `git add`. Harmless unless someone clones with
  `--recurse-submodules`.

## The two blockers everything below runs into

1. **`patches/system-overlay/` is scaffolded but not implemented.**
   `scripts/build.sh` explicitly warns and does nothing if that directory
   exists — rewriting `product`/`system`/`vendor` images needs
   `erofs-utils`/`e2fsprogs` tooling that hasn't been built or verified
   against real Pong partitions. This is the actual reason "just delete the
   Nothing apps from `product.img`" isn't a today-sized task.
2. **Nobody has pulled `image-logical.7z` yet** (the archive holding
   `product`/`system`/`system_ext`/`vendor`/`vendor_dlkm` — where Nothing's
   preinstalled apps actually live). Every fact the research report has about
   *stock's* app inventory is inferred from what LineageOS's own
   `proprietary-files.txt` pulls or doesn't pull from a real dump, not from
   this repo's own copy of one, because this repo doesn't have one yet.
   Confirming exact package names/paths for this specific
   `Pong_B4.1-260618-1026` build needs that download.

## Plan

### 1. `debloat` — userspace pass first, image rewrite only if that's not enough

Don't start with image rewriting. Start with what `adb-root` already unlocks:
root ADB. `pm disable-user --user 0 <pkg>` / `pm uninstall --user 0 <pkg>` run
against a live, booted device needs **no new image tooling** — reversible,
doesn't touch the unimplemented `system-overlay` path, and is the same
mechanism community debloat tools use on this device. Practically: a
`scripts/debloat.sh` that takes a package list and shells `adb` commands,
paired with `adb-root` so it runs non-interactively.

What research report §2 gives you for that package list: which *categories*
are safe (every consumer-facing Nothing app — Camera, X, Recorder, Weather,
Essential Space, Dot Notes, Community — is absent from a working LineageOS
build with no reported breakage) and exactly which six packages are
load-bearing and must stay (`CACertService`, `CneApp`,
`NothingAudioEffectService`, `TimeService`, `IWlanService`, `uimgbaservice` —
confirmed from LineageOS's real `proprietary-files.txt`, not guessed). It does
**not** hand you exact stock package names — LineageOS never had those apps to
enumerate. **Step 0 of this branch is pulling `image-logical.7z`** (or just the
`product`/`system_ext` partitions) and running
`ls product/priv-app system/priv-app system_ext/priv-app` for real, then
cross-referencing against the safe/keep split above.

If the userspace pass isn't enough — you want the storage back, not just a
disabled app, or you want stock's launcher/Glyph gone from the image itself —
that's when `patches/system-overlay` needs to actually get built. Treat that
as its own follow-on branch (e.g. `system-overlay-tooling`), not bundled into
`debloat`: it's a meaningfully bigger lift (loop-mounting erofs/ext4,
resizing, re-signing) and the userspace pass gets most of the practical
benefit for a fraction of the risk.

### 2. `glyph-custom` — optional, low priority, do only on request

Not needed for debloat — stock's Glyph app can just stay off the removal list;
it's a headline device feature, not bloat. Only relevant if the goal shifts
from "remove Nothing's software" to "replace it with something open."
`org.lineageos.glyph` (research report §1.2) is a real, working precedent —
call/charging/powershare/flip-to-mute/music-visualizer/volume flashes, two
Quick Settings tiles, driving the same Awinic AW20036 LED IC Pong ships. Its
ceiling is LineageOS's feature set, not stock's: no Composer, no Toys, no
third-party SDK, no delivery-partner integrations — those need Nothing's
closed backend, which no open reimplementation reaches. A third-party APK
getting the sysfs access it needs would ride on `adb-root`'s root grant, not
on `system-overlay` — so this doesn't share debloat's blocker — but it's also
not scoped or estimated beyond "LineageOS proved it's possible."

### 3. AVB / verified-boot follow-up — not a branch, a flag for later

`adb-root`'s own `patches/README.md` already documents that its repacked
`vendor_boot.img` carries no AVB footer and expects the orange
unlocked-bootloader warning, consistent with research report §4.2. The one
open question the research left unresolved — whether Pong's bootloader
supports `avb_custom_key` re-locking to a yellow state instead of orange —
still isn't answered by anything built so far. Worth a cheap, isolated test
(`fastboot flash avb_custom_key`, see if it's accepted) before deciding
whether it's worth chasing. Doesn't block anything above.

## Suggested order

`debloat` (userspace pass) → decide if `system-overlay-tooling` is worth
building → `glyph-custom` only if actually wanted. Kernel work
(`kernel-optimized`, `kernel-clean`) is a fully separate track, unaffected by
any of this.
