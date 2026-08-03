#!/usr/bin/env sh
# Basic Memory & CPU Benchmark

echo "=== System Baseline ==="
echo "MGLRU Status:"
cat /sys/kernel/mm/lru_gen/enabled

echo ""
echo "=== Pinning CPUs to Max Performance ==="
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo "performance" > "$gov" 2>/dev/null || true
done
sleep 2

echo ""
echo "=== Dropping Memory Caches ==="
echo 3 > /proc/sys/vm/drop_caches
sleep 1

echo ""
echo "=== Memory Bandwidth Benchmark (Read/Write to NULL) ==="
# Test memory throughput via zero-to-null copy
dd if=/dev/zero of=/dev/null bs=1M count=2000 2>&1 | grep copied

echo ""
echo "=== Restoring CPU Governors ==="
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo "schedutil" > "$gov" 2>/dev/null || true
done
echo "Done! System restored."
