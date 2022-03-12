#!/bin/bash

dd_file_range_old() {
	#assume dd has not supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=$5
	local BS=$((16*1024))

	local fsize=$(stat -c%s "$if") || return $?
	[[ -z "$of" ]] && return 1
	touch "$of" || return $?
	((seek > 0)) && {
		local orig_of=$of
		local tmpof=/tmp/.of.tmp-$$
		of=$tmpof
	}

	local Q= R= Q2= R2= NREAD=

	((fsize <= BS)) && BS=$skip
	Q=$((skip/BS))  #quotient
	R=$((skip%BS))  #residue
	NREAD=$((BS-R))
	dd if="$if" ibs=$BS skip=$Q count=1 | tail -c $NREAD >"$of"

	if [[ -z "$len" ]]; then
		dd if="$if" ibs=$BS skip=$((Q+1)) oflag=append conv=notrunc of="$of"
	else
		if ((NREAD > len)); then
			truncate --size=${len} "$of"
		else
			let len-=$NREAD
			Q2=$((len/BS))  #quotient
			R2=$((len%BS))  #residue
			((Q2>0)) && dd if="$if" ibs=$BS skip=$((Q+1)) count=$Q2 oflag=append conv=notrunc of="$of"
			((R2>0)) && dd if="$if" ibs=$BS skip=$((Q+1+Q2)) count=1 | head -c $R2 >>"$of"
		fi
	fi

	((seek > 0)) && {
		echo 0000000000000000000000000000000000000000000
		cat $of
		echo 0000000000000000000000000000000000000000000
		Q=$((seek/BS))
		R=$((seek%BS))
		{ dd if="$orig_of" ibs=$BS skip=$Q count=1 | head -c $R; dd if="$of" bs=$BS; } |
			dd of="$orig_of" obs=$BS seek=$Q conv=notrunc
		rm -vf "$tmpof"
	}
}

dd_file_range() {
	#assume dd has supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=$5
	local BS=$((64*1024))

	local fsize=$(stat -c%s "$if") || return $?
	[[ -z "$of" ]] && return 1
	touch "$of" || return $?

	if [[ -z "$len" ]]; then
		dd if="$if" of="$of" bs=${BS}c skip=$skip seek=$seek iflag=skip_bytes oflag=seek_bytes conv=notrunc
	else
		local Q R
		Q=$((len/BS))
		R=$((len%BS))
		((Q>0)) && dd if="$if" of="$of" bs=${BS}c count=$Q skip=$skip seek=$seek iflag=skip_bytes oflag=seek_bytes conv=notrunc
		((R>0)) && dd if="$if" of="$of" bs=${R}c count=1 skip=$((skip+BS*Q)) seek=$((seek+BS*Q)) iflag=skip_bytes oflag=seek_bytes conv=notrunc
	fi
}

args=()
for arg; do
	case "$arg" in
	-skip=*) _skip=${arg/*=/};;
	-seek=*) _seek=${arg/*=/};;
	-len=*)  _len=${arg/*=/};;
	-*)      : echo "{warn} unkown option '${arg}'";;
	*)       args+=($arg);;
	esac
done
eval set -- "${args[@]}"
[[ $# -lt 2 ]] && {
	cat <<-COMM
	Usage: $0 <ifile> <ofile> [[-skip= | -seek= | -len=]...] [skip [seek [len]]]

	Examples:
	  $0 ifile ofile 4096 -len=\$((64*1024))
	  $0 ifile ofile -seek=\$((8*1024))
	COMM
	exit 1
}

if=$1; of=$2; shift 2;
read skip seek len <<<"$*"
skip=${skip:-${_skip:-0}}
seek=${seek:-${_seek:-0}}
len=${len:-${_len}}

#dd_file_range_old "$if" "$of" $skip $seek $len
dd_file_range "$if" "$of" $skip $seek $len
