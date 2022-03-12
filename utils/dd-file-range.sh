#!/bin/bash

dd_file_range_old() {
	#assume dd has not supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=$5
	local BS=$((16*1024))
	local fn=${FUNCNAME[0]}
	local logOpt=${LogOpt:-status=none}

	local fsize=$(stat -c%s "$if") || return $?
	((skip >= fsize)) && {
		echo "[$fn:err] skip beyond the EOF of $if" >&2
		return 1
	}
	local alen=$((fsize-skip))
	((len > alen)) && {
		len=$alen
		echo "[$fn:err] (skip+len) beyond the EOF of $if" >&2
	}
	[[ -z "$of" ]] && return 1
	touch "$of" || return $?

	local tmpof=$(mktemp)
	local Q= R= Q2= R2= NREAD=

	((fsize <= BS)) && BS=$skip
	Q=$((skip/BS))  #quotient
	R=$((skip%BS))  #residue
	NREAD=$((BS-R))
	dd if="$if" ibs=$BS skip=$Q count=1 $logOpt | tail -c $NREAD >$tmpof

	if [[ -z "$len" ]]; then
		((alen > NREAD)) &&
			dd if="$if" ibs=$BS skip=$((Q+1)) oflag=append conv=notrunc of="$tmpof" $logOpt
	else
		if ((len > NREAD)); then
			let len-=$NREAD
			Q2=$((len/BS))  #quotient
			R2=$((len%BS))  #residue
			((Q2>0)) && dd if="$if" ibs=$BS skip=$((Q+1)) count=$Q2 oflag=append conv=notrunc of="$tmpof" $logOpt
			((R2>0)) && dd if="$if" ibs=$BS skip=$((Q+1+Q2)) count=1 $logOpt | head -c $R2 >>"$tmpof"
		else
			truncate --size=${len} "$tmpof"
		fi
	fi

	if ((seek > 0)); then
		Q=$((seek/BS))
		R=$((seek%BS))
		{
		dd if="$of" ibs=$BS skip=$Q count=1 $logOpt | head -c $R
		dd if="$tmpof" bs=$BS $logOpt
		} | dd of="$of" obs=$BS seek=$Q conv=notrunc $logOpt
	else
		dd if="$tmpof" of="$of" bs=$BS conv=notrunc $logOpt
	fi
	rm -f "$tmpof"
}

dd_file_range() {
	#assume dd has supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=$5
	local BS=$((64*1024))
	local fn=${FUNCNAME[0]}
	local logOpt=${LogOpt:-status=none}

	local fsize=$(stat -c%s "$if") || return $?
	((skip >= fsize)) && {
		echo "[$fn:err] skip beyond the EOF of $if" >&2
		return 1
	}
	local alen=$((fsize-skip))
	((len > alen)) && {
		len=$alen
		echo "[$fn:err] (skip+len) beyond the EOF of $if" >&2
	}
	[[ -z "$of" ]] && return 1
	touch "$of" || return $?

	if [[ -z "$len" ]]; then
		dd if="$if" of="$of" bs=${BS}c skip=$skip seek=$seek iflag=skip_bytes oflag=seek_bytes conv=notrunc $logOpt
	else
		local Q R
		Q=$((len/BS))
		R=$((len%BS))
		((Q>0)) && dd if="$if" of="$of" bs=${BS}c count=$Q skip=$skip seek=$seek iflag=skip_bytes oflag=seek_bytes conv=notrunc $logOpt
		((R>0)) && dd if="$if" of="$of" bs=${R}c count=1 skip=$((skip+BS*Q)) seek=$((seek+BS*Q)) iflag=skip_bytes oflag=seek_bytes conv=notrunc $logOpt
	fi
}

args=()
for arg; do
	case "$arg" in
	-skip=*) _skip=${arg/*=/};;
	-seek=*) _seek=${arg/*=/};;
	-len=*)  _len=${arg/*=/};;
	-log=*)  _logLevel=${arg/*=/};;
	-ver=*)  _ver=${arg/*=/};;
	-*)      :;;
	*)       args+=($arg);;
	esac
done
eval set -- "${args[@]}"
[[ $# -lt 2 ]] && {
	cat <<-COMM
	Usage: $0 <ifile> <ofile> [skip [seek [len]]] [[-skip=|-seek=|-len=|-log=<noxfer|progress>]...]

	Examples:
	  $0 ifile ofile 4096 -len=\$((64*1024))
	  $0 ifile ofile -seek=\$((8*1024))

	Tests:
	  echo -n "0123456789abcdef" >a; echo -n "^*******************************" >b
	  $0 a b 3 8  4;  sed "s/$/\n/" b
	  $0 a b 3 8  6;  sed "s/$/\n/" b
	  $0 a b 3 8  8;  sed "s/$/\n/" b
	  $0 a b 3 8  10; sed "s/$/\n/" b
	  $0 a b 3 8  12; sed "s/$/\n/" b
	  $0 a b 3 8  14; sed "s/$/\n/" b
	  $0 a b 3 8  16; sed "s/$/\n/" b
	  $0 a b 3 64 13; sed "s/$/\n/" b
	  rm -f a b
	COMM
	exit 1
}

if=$1; of=$2; shift 2;
read skip seek len <<<"$*"
skip=${skip:-${_skip:-0}}
seek=${seek:-${_seek:-0}}
len=${len:-${_len}}
LogOpt=status=${_logLevel:-none}
if [[ -n "$_ver" ]]; then
	case "$_ver" in
	o*) dd_file_range_old "$if" "$of" $skip $seek $len;;
	*)  dd_file_range "$if" "$of" $skip $seek $len;;
	esac
elif dd --help|grep -q skip_bytes; then
	dd_file_range "$if" "$of" $skip $seek $len
else
	dd_file_range_old "$if" "$of" $skip $seek $len
fi
