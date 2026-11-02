#!/bin/sh
# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Check that the PoopLinux options actually took effect in a built config.
#
#   tools/pooplinux/check-config.sh <x86_64|arm64>

arch=${1:?usage: $0 <x86_64|arm64>}
srctree=$(cd "$(dirname "$0")/../.." && pwd)
config=${O:-$srctree/out/$arch}/.config

want="CONFIG_LTO_CLANG_THIN=y
CONFIG_PREEMPT_LAZY=y
CONFIG_PREEMPT_DYNAMIC=y
CONFIG_HZ_1000=y
CONFIG_DEBUG_INFO_NONE=y
# CONFIG_SLUB_DEBUG is not set
CONFIG_DEFAULT_BBR=y
CONFIG_DEFAULT_FQ=y
CONFIG_LRU_GEN_ENABLED=y"
[ "$arch" = x86_64 ] && want="$want
CONFIG_KERNEL_LZ4=y"

fail=0
echo "$want" | while IFS= read -r line; do
	if grep -qxF "$line" "$config"; then
		echo "ok   $line"
	else
		echo "FAIL $line"
		exit 1
	fi
done || fail=1
exit $fail
