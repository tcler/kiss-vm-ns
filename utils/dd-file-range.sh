#!/bin/bash

dd_range() {
	local if=$1
	local of=$2
	local SKIP=${3:-0}
	local SIZE=$4
	local BS=$((8 * 1024))
	local Q= R= Q2= R2= NREAD=

	[[ -z "$of" ]] && return 1
	local fsize=$(stat -c%s "$if") || return $?

	((fsize <= BS)) && BS=$SKIP
	Q=$((SKIP/BS))  #quotient
	R=$((SKIP%BS))  #residue
	NREAD=$((BS-R))
	dd if=$if ibs=$BS skip=$Q count=1 | tail -c $NREAD >$of

	if [[ -z "$SIZE" ]]; then
		dd if=$if bs=$BS skip=$((Q+1)) oflag=append conv=notrunc of=$of
	else
		if ((NREAD > SIZE)); then
			truncate --size=${SIZE} $of
			return 0
		fi
		let SIZE-=$NREAD
		Q2=$((SIZE/BS))  #quotient
		R2=$((SIZE%BS))  #residue
		((Q2>0)) && dd if=$if bs=$BS skip=$((Q+1)) count=$Q2 oflag=append conv=notrunc of=$of
		((R2>0)) && dd if=$if bs=$BS skip=$((Q+1+Q2)) count=1 | head -c $R2 >>$of
	fi
}

dd_range "$@"
