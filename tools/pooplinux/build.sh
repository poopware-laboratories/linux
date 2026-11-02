#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Build a PoopLinux kernel with LLVM.
#
#   tools/pooplinux/build.sh <x86_64|arm64> [extra.config ...]
#
# Output goes to $O (default: out/<arch>). Extra fragments, e.g.
# pooplinux-nomitigations.config, are merged after pooplinux.config.
# $TARGETS selects the make targets (default: the full build), e.g.
# TARGETS=Image or TARGETS=bzImage to build only the boot image.
# CONFIG_ONLY=1 stops after the configuration step.

set -e

arch=${1:?usage: $0 <x86_64|arm64> [extra.config ...]}
shift

case $arch in
x86_64)	karch=x86;   defconfig=x86_64_defconfig; image=arch/x86/boot/bzImage ;;
arm64)	karch=arm64; defconfig=defconfig;        image=arch/arm64/boot/Image ;;
*)	echo "unknown arch: $arch" >&2; exit 1 ;;
esac

srctree=$(cd "$(dirname "$0")/../.." && pwd)
out=${O:-$srctree/out/$arch}
make=make
jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN)

if [ "$(uname -s)" = Darwin ]; then
	# kbuild needs GNU tools and an ELF linker; the source tree must be
	# on a case-sensitive filesystem (see tools/pooplinux/README).
	brew=$(brew --prefix)
	for p in gnu-sed/libexec/gnubin findutils/libexec/gnubin \
		 coreutils/libexec/gnubin llvm/bin lld/bin; do
		PATH=$brew/opt/$p:$PATH
	done
	export PATH
	make=gmake
	extra="HOSTCFLAGS=-I$brew/opt/libelf/include HOSTLDFLAGS=-L$brew/opt/libelf/lib"
fi

$make -C "$srctree" O="$out" ARCH=$karch LLVM=1 $extra \
	$defconfig pooplinux.config "$@"
[ -n "$CONFIG_ONLY" ] && { echo "$out/.config"; exit 0; }
$make -C "$srctree" O="$out" ARCH=$karch LLVM=1 $extra -j"$jobs" $TARGETS

echo "$out/$image"
