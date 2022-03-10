#!/bin/bash

dd_range() {
	local if=$1
	local of=$2
	local SKIP=${3:-0}
	local SIZE=$4
	local BS=$((8 * 1024))

	[[ -z "$of" ]] && return 1

	Q=$((SKIP/BS))  #quotient
	R=$((SKIP%BS))  #residue
	dd if=$if ibs=$BS skip=$Q count=1 | tail -c $((BS-R)) >$of

	{
	if [[ -z "$SIZE" ]]; then
		dd if=$if bs=$BS skip=$((Q+1))
	else
		Q=$((SIZE/BS))  #quotient
		R=$((SIZE%BS))  #residue
		((Q>0)) && dd if=$if bs=$BS skip=1 count=$Q
		((R>0)) && dd if=$if bs=$BS skip=$((Q+1)) count=1 | head -c $R
	fi
	} >>$of
}

dd_range "$@"
