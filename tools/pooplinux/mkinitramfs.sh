#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Build a tiny busybox initramfs for smoke-testing a kernel in QEMU.
#
#   tools/pooplinux/mkinitramfs.sh <x86_64|arm64> <output.cpio.gz> [script]
#
# BUSYBOX must point to a statically linked busybox for the target
# architecture; it defaults to the host's busybox when the host
# architecture matches. If a script is given, /init runs it and powers
# off; otherwise /init starts an interactive shell on the console.

set -e

arch=${1:?usage: $0 <x86_64|arm64> <output.cpio.gz> [script]}
output=${2:?usage: $0 <x86_64|arm64> <output.cpio.gz> [script]}
script=$3

case $arch in
x86_64)	want=x86-64 ;;
arm64)	want=aarch64 ;;
*)	echo "unknown arch: $arch" >&2; exit 1 ;;
esac

busybox=${BUSYBOX:-$(command -v busybox || true)}
if [ -z "$busybox" ] || ! file -L "$busybox" | grep -q "$want"; then
	echo "need a static $arch busybox: set BUSYBOX=/path/to/busybox" >&2
	exit 1
fi
if ! file -L "$busybox" | grep -q 'statically linked'; then
	echo "$busybox is not statically linked" >&2
	exit 1
fi

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/bin" "$root/dev" "$root/proc" "$root/sys" "$root/tmp"
cp "$busybox" "$root/bin/busybox"
ln -s busybox "$root/bin/sh"

cat > "$root/init" <<'INIT'
#!/bin/sh
/bin/busybox --install -s /bin
export PATH=/bin
mount -t devtmpfs dev /dev 2>/dev/null
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
ip link set lo up
if [ -x /test.sh ]; then
	/test.sh
else
	echo "PoopLinux smoke-test shell; 'poweroff -f' to exit"
	setsid cttyhack sh
fi
poweroff -f
INIT
chmod +x "$root/init"

if [ -n "$script" ]; then
	cp "$script" "$root/test.sh"
	chmod +x "$root/test.sh"
fi

(cd "$root" && find . | cpio -o -H newc --owner=0:0 --quiet) | gzip -9 > "$output"
echo "$output"
