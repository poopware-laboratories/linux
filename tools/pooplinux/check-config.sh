#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Check that the PoopLinux options actually took effect in a .config.
#
#   tools/pooplinux/check-config.sh <x86_64|arm64> [max]
#
# Reads $O/.config (default: out/<arch>, or out/<arch>-max with "max").

arch=${1:?usage: $0 <x86_64|arm64> [max]}
tier=$2
srctree=$(cd "$(dirname "$0")/../.." && pwd)
config=${O:-$srctree/out/$arch${tier:+-$tier}}/.config
[ -f "$config" ] || { echo "$config not found" >&2; exit 1; }

on="LTO_CLANG_THIN PREEMPT_LAZY PREEMPT_DYNAMIC HZ_1000 DEBUG_INFO_NONE
    DEFAULT_BBR DEFAULT_FQ LRU_GEN_ENABLED ZSWAP_DEFAULT_ON
    ZSWAP_COMPRESSOR_DEFAULT_LZ4 ZRAM NTSYNC DEFERRED_STRUCT_PAGE_INIT"
off="SLUB_DEBUG"
[ "$arch" = x86_64 ] && on="$on KERNEL_LZ4"
if [ "$tier" = max ]; then
	on="$on INIT_STACK_NONE TRANSPARENT_HUGEPAGE_ALWAYS"
	off="$off AUDIT STACKPROTECTOR"
	case $arch in
	x86_64)	off="$off CPU_MITIGATIONS" ;;
	arm64)	off="$off UNMAP_KERNEL_AT_EL0 ARM64_PTR_AUTH_KERNEL
		     ARM64_BTI_KERNEL" ;;
	esac
fi

fail=0
for o in $on; do
	if grep -qx "CONFIG_$o=y" "$config"; then
		echo "ok   CONFIG_$o=y"
	else
		echo "FAIL CONFIG_$o=y ($(grep -E "^(# )?CONFIG_$o[= ]" "$config" || echo absent))"
		fail=1
	fi
done
for o in $off; do
	if grep -qE "^CONFIG_$o=[ym]" "$config"; then
		echo "FAIL CONFIG_$o off ($(grep "^CONFIG_$o=" "$config"))"
		fail=1
	else
		echo "ok   CONFIG_$o off"
	fi
done
exit $fail
