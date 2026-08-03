#!/usr/bin/env bash
# Kernel build script for GCE VM, protected by a lock guard to prevent concurrent build corruption.
set -euo pipefail

# Lock guard: ensure only one build runs at a time in this tree
(
  flock -n 9 || { echo "FATAL: Another build is currently running in this tree. Aborting."; exit 1; }
  
  echo "--- Starting clean kernel build ---"
  
  # Ensure dependencies
  sudo apt-get install -y pigz || true

  # Stamp 4.1 for anti-rollback
  sed -i 's/^export OS=.*/export OS="16.0.0"/;s/^export SPL=.*/export SPL="2026-06"/' build_kernel.sh

  TOOLS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy \
         OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip \
         HOSTCC=gcc LLVM_IAS=1"

  echo "--- Generating config ---"
  cp defconfig .config
  scripts/kconfig/merge_config.sh -m .config \
      ../cfg/patches/kernel-optimized/pong_optimized.fragment \
      ../cfg/patches/kernel-optimized/pong_performance_overlay.fragment
  
  make ARCH=arm64 $TOOLS olddefconfig

  # GATE — do not build if either check fails
  grep -q '^CONFIG_LTO_CLANG_THIN=y' .config || { echo "FATAL: LTO off"; exit 1; }
  grep -q '^CONFIG_LRU_GEN=y'        .config || { echo "FATAL: no MGLRU"; exit 1; }
  grep -q '^CONFIG_DAMON=y'          .config || { echo "FATAL: no DAMON"; exit 1; }
  grep -q '^CONFIG_LAZY_INITCALL=y'  .config || { echo "FATAL: no LAZY_INITCALL"; exit 1; }

  echo "--- Cleaning old objects ---"
  make ARCH=arm64 $TOOLS clean

  echo "--- Compiling ---"
  make ARCH=arm64 $TOOLS -j$(nproc) Image.gz

  echo "--- Packaging boot.img ---"
  ./build_kernel.sh skip
  
  echo "--- Build complete. Final image: arter97-kernel-r45b2-boot.img ---"

) 9> build.lock
