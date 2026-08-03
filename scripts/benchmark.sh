#!/usr/bin/env bash
# Kernel MGLRU Benchmark Script
# Run as root: su -c ./scripts/benchmark.sh
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "FATAL: This script must be run as root."
  exit 1
fi

echo "--- Setting up measurement environment ---"
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo "performance" > "$gov" 2>/dev/null || true
done
echo "Governors pinned to performance."

echo "Waiting for thermal stabilization (cooling down for 5 seconds)..."
sleep 5

echo "--- Starting Benchmark ---"
# Check MGLRU
if [[ -f /sys/kernel/mm/lru_gen/enabled ]]; then
  echo -n "Current MGLRU state: "
  cat /sys/kernel/mm/lru_gen/enabled
else
  echo "MGLRU toggle not found!"
fi

echo ""
echo "Measuring App Launch Times (Cold Start)..."
echo "Dropping memory caches..."
echo 3 > /proc/sys/vm/drop_caches
sleep 1

# Launch Settings app
echo "Launching com.android.settings..."
am start -W com.android.settings | grep -iE "TotalTime|WaitTime" || true
am force-stop com.android.settings

echo ""
echo "Dropping memory caches again..."
echo 3 > /proc/sys/vm/drop_caches
sleep 1

# Launch YouTube (if installed, otherwise falls back gracefully)
echo "Launching com.google.android.youtube..."
am start -W com.google.android.youtube | grep -iE "TotalTime|WaitTime" || true
am force-stop com.google.android.youtube

echo ""
echo "Measuring baseline CPU/Memory throughput..."
dd if=/dev/zero of=/dev/null bs=1M count=2000 2>&1 | grep copied

echo "--- Cleanup ---"
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo "schedutil" > "$gov" 2>/dev/null || true
done
echo "Governors restored to schedutil."
