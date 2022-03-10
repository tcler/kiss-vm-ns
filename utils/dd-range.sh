#!/bin/bash

dd_range() {
	local if=$1
	local of=$2
	local SKIP=${3:-0}
	local SIZE=$4
	local BS=$((8 * 1024))

	[[ -z "$of" ]] && return 1

	dd if=$if bs=$BS count=1 | dd iflag=fullblock,skip_bytes ibs=$SKIP skip=1 >$of
	if [[ -z "$SIZE" ]]; then
		dd if=$if bs=$BS skip=1 >>$of
	else
		CNT=$((SIZE/BS + 1))
		dd if=$if bs=$BS skip=1 count=$CNT >>$of
		truncate --size=${SIZE} $of
	fi
}

dd_range "$@"
