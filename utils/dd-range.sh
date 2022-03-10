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
		Q2=$((SIZE/BS))  #quotient
		R2=$((SIZE%BS))  #residue
		((Q2>0)) && dd if=$if bs=$BS skip=$((Q+1)) count=$Q2
		((R2>0)) && dd if=$if bs=$BS skip=$((Q+1+Q2)) count=1 | head -c $R2
	fi
	} >>$of
}

dd_range "$@"
