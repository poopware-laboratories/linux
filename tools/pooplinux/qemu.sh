#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Boot a PoopLinux kernel built by build.sh in QEMU.
#
#   tools/pooplinux/qemu.sh <x86_64|arm64> [kernel cmdline ...]
#
# Environment:
#   O        build directory (default: out/<arch>)
#   KERNEL   kernel image (default: the boot image in $O)
#   INITRD   initramfs, e.g. from mkinitramfs.sh
#   DISK     disk image attached as virtio-blk (/dev/vda); without
#            INITRD the kernel boots with root=/dev/vda
#   MEM      guest memory (default: 1G)
#   SMP      guest CPUs (default: 2)
#   ACCEL    kvm, hvf or tcg (default: kvm/hvf when usable, else tcg)
#   QEMU_EXTRA  extra arguments appended to the QEMU command line
#
# The console is the serial port on stdio; exit with Ctrl-A x.
# A guest poweroff, reboot or panic terminates QEMU.

set -e

arch=${1:?usage: $0 <x86_64|arm64> [kernel cmdline ...]}
shift

srctree=$(cd "$(dirname "$0")/../.." && pwd)
out=${O:-$srctree/out/$arch}

case $arch in
x86_64)
	qemu=qemu-system-x86_64
	image=$out/arch/x86/boot/bzImage
	machine="-M q35"
	console=ttyS0
	;;
arm64)
	qemu=qemu-system-aarch64
	image=$out/arch/arm64/boot/Image
	machine="-M virt"
	console=ttyAMA0
	;;
*)	echo "unknown arch: $arch" >&2; exit 1 ;;
esac

kernel=${KERNEL:-$image}
[ -f "$kernel" ] || { echo "$kernel not found; run build.sh first" >&2; exit 1; }

host=$(uname -m)
case $host in arm64) host=aarch64 ;; esac
case $arch in arm64) guest=aarch64 ;; *) guest=$arch ;; esac

if [ -z "$ACCEL" ]; then
	ACCEL=tcg
	if [ "$host" = "$guest" ]; then
		if [ "$(uname -s)" = Darwin ]; then
			[ "$(sysctl -n kern.hv_support 2>/dev/null)" = 1 ] && ACCEL=hvf
		elif [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
			ACCEL=kvm
		fi
	fi
fi

cpu=max
# Pointer authentication with the architected QARMA algorithm is very
# slow to emulate; the implementation-defined one is much cheaper.
[ "$ACCEL" = tcg ] && [ "$arch" = arm64 ] && cpu=max,pauth-impdef=on

append="console=$console panic=-1"
if [ -n "$DISK" ] && [ -z "$INITRD" ]; then
	append="$append root=/dev/vda rw"
fi
[ $# -gt 0 ] && append="$append $*"

set -- $machine -accel "$ACCEL" -cpu "$cpu" \
	-m "${MEM:-1G}" -smp "${SMP:-2}" \
	-nographic -no-reboot \
	-kernel "$kernel" -append "$append" \
	-netdev user,id=net0 -device virtio-net-pci,netdev=net0
[ -n "$INITRD" ] && set -- "$@" -initrd "$INITRD"
[ -n "$DISK" ] && set -- "$@" \
	-drive file="$DISK",if=none,id=disk0,format="${DISK_FORMAT:-raw}" \
	-device virtio-blk-pci,drive=disk0

# QEMU_EXTRA is intentionally word-split
exec $qemu "$@" $QEMU_EXTRA
