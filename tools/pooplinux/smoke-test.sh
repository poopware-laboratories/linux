#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Boot a kernel built by build.sh to a busybox initramfs, run a few
# checks and power off. Fails if the boot hangs (TIMEOUT seconds,
# default 300) or the expected output is missing.
#
#   BUSYBOX=/path/to/static/busybox tools/pooplinux/smoke-test.sh <x86_64|arm64>
#
# Boots the build in $O (default: out/<arch>); the log is saved as
# $O/smoke-test.log.

set -e

arch=${1:?usage: $0 <x86_64|arm64>}
dir=$(cd "$(dirname "$0")" && pwd)
srctree=$(cd "$dir/../.." && pwd)
out=${O:-$srctree/out/$arch}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/test.sh" <<'TEST'
#!/bin/sh
echo "=== SMOKE BEGIN"
uname -a
echo "--- preempt"
cat /sys/kernel/debug/sched/preempt 2>/dev/null || dmesg | grep -i preempt
echo "--- tcp_congestion_control"
cat /proc/sys/net/ipv4/tcp_congestion_control
echo "--- default_qdisc"
cat /proc/sys/net/core/default_qdisc
echo "--- cmdline"
cat /proc/cmdline
echo "--- transparent_hugepage"
cat /sys/kernel/mm/transparent_hugepage/enabled
echo "--- zswap"
cat /sys/module/zswap/parameters/enabled /sys/module/zswap/parameters/compressor
echo "--- vulnerabilities"
for f in /sys/devices/system/cpu/vulnerabilities/*; do
	echo "${f##*/}: $(cat "$f")"
done
echo "=== SMOKE END"
poweroff -f
TEST

"$dir/mkinitramfs.sh" "$arch" "$tmp/initramfs.cpio.gz" "$tmp/test.sh" >/dev/null

rc=0
INITRD=$tmp/initramfs.cpio.gz timeout "${TIMEOUT:-300}" \
	env O="$out" "$dir/qemu.sh" "$arch" quiet </dev/null >"$tmp/log" 2>&1 || rc=$?
tr -d '\r' < "$tmp/log" > "$out/smoke-test.log"
log=$out/smoke-test.log

if [ $rc = 124 ]; then
	echo "FAIL: boot timed out after ${TIMEOUT:-300}s (log: $log)" >&2
	exit 1
fi
sed -n '/^=== SMOKE BEGIN/,/^=== SMOKE END/p' "$log"
if ! grep -q '^=== SMOKE END' "$log"; then
	echo "FAIL: test did not complete (qemu rc=$rc, log: $log)" >&2
	exit 1
fi
grep -q -- '-poop' "$log" || { echo "FAIL: not a -poop kernel" >&2; exit 1; }
grep -qx bbr "$log" || { echo "FAIL: congestion control is not bbr" >&2; exit 1; }
echo "PASS"
