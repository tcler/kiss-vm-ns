#!/bin/bash
#auth: Jianhong <yin-jianhong@163.com>
#version: 1.2
#
#this program is used to copy a range of data from one file to another
#like syscall copy_file_range(2) on linux kernel-5.3 or FreeBSD-13
#
#and could also use the xfs_io->copy_range sub-command in newer linux
#distributions instead

dd_file_range_old() {
	#assume dd has not supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=${5}
	local BS=${BSIZE:-$((16*1024))}
	local fn=${FUNCNAME[0]}
	local logOpt=${LogOpt:-status=none}

	local ifsize=$(stat -c%s "$if") || return $?
	((skip >= ifsize)) && {
		echo "[$fn:err] skip beyond the EOF of $if" >&2
		return 1
	}
	local alen=$((ifsize-skip))
	len=${len:-$alen}
	((len > alen)) && {
		len=$alen
		echo "[$fn:warn] (skip+len) beyond the EOF of $if" >&2
	}
	if [[ -n "$of" ]]; then touch "$of" || return $?; else seek=0; fi

	local stat=$(dd --help|grep status=)
	if [[ -z "$stat" ]]; then  #RHEL-4
		[[ $logOpt = *=none ]] && { exec 2>/dev/null; }
		logOpt=
	elif [[ "$stat" = *=noxfer ]]; then  #RHEL-5
		[[ $logOpt = *=none ]] && { exec 2>/dev/null; logOpt=status=noxfer; }
		[[ $logOpt = *=prg* ]] && logOpt=
	fi

	local tmpof=$if
	if ((skip > 0 || len < ifsize)); then
		tmpof=$(mktemp)
		local Q=0 R= Q2= R2= NSKIP=0 NREAD=0
		local iBS=$BS
		((ifsize <= BS)) && iBS=$ifsize

		#if the skip_offset is not aligned with the step(iBS)
		#+---------------+---------------+---------------+----
		#|     iBS       |//////iBS//////|      iBS      |****
		#+---------------+--R--*--NREAD--+---------------+----
		#      (Q*iBS)__/      |/////?///|
		#              offset<-+     |   +->NSKIP
		#                            |
		#                            `-->(NREAD > len ?)
		R=$((skip%iBS))  #residue
		if ((R > 0)); then
			Q=$((skip/iBS))  #quotient
			NREAD=$((iBS-R))
			NSKIP=$((Q+1))
			if [[ -n "$of" ]]; then
				dd if="$if" ibs=$iBS skip=$Q count=1 $logOpt |
					tail -c $NREAD |
					head -c $((NREAD > len ? len : NREAD)) >$tmpof
			else
				dd if="$if" ibs=$iBS skip=$Q count=1 $logOpt |
					tail -c $NREAD |
					head -c $((NREAD > len ? len : NREAD))
			fi
		fi

		#if the skip_offset is not aligned with the step(iBS)
		#---+---------------+---------------+---------------+--
		#***|     iBS       |//////iBS//////|//////iBS      |**
		#---+--R--*--NREAD--+---------------+--R2--*--------+--
		#         |\\\\\\\\\|//////////////////////|
		# offset<-+         +->NSKIP               +->end(offset+len)
		#         |         \________nlen_________/|
		#         \_____________len________________/
		if ((len > NREAD)); then
			local nlen=$((len-NREAD))
			Q2=$((nlen/iBS))  #quotient
			R2=$((nlen%iBS))  #residue
			if [[ -n "$of" ]]; then
				((Q2>0)) && dd if="$if" ibs=$iBS skip=$NSKIP count=$Q2 oflag=append conv=notrunc of="$tmpof" $logOpt
				((R2>0)) && dd if="$if" ibs=$iBS skip=$((NSKIP+Q2)) count=1 $logOpt | head -c $R2 >>"$tmpof"
			else
				((Q2>0)) && dd if="$if" ibs=$iBS skip=$NSKIP count=$Q2 $logOpt
				((R2>0)) && dd if="$if" ibs=$iBS skip=$((NSKIP+Q2)) count=1 $logOpt | head -c $R2
			fi
		fi
	fi

	if ((seek > 0)); then
		local ofsize=$(stat -c%s "$of")
		((seek > ofsize)) && dd if=/dev/zero bs=1c seek=$seek count=0 of="$of" $logOpt
		Q=$((seek/BS))
		R=$((seek%BS))
		{
		dd if="$of" ibs=$BS skip=$Q count=1 $logOpt | head -c $R
		dd if="$tmpof" bs=$BS $logOpt
		} | dd of="$of" obs=$BS seek=$Q conv=notrunc $logOpt
	else
		if [[ -n "$of" ]]; then
			dd if="$tmpof" "of=$of" bs=$BS conv=notrunc $logOpt
		else
			cat "$tmpof"
		fi
	fi
	[[ "$if" != "$tmpof" ]] && rm -f -- "$tmpof"
}

dd_file_range() {
	#assume dd has supported skip_bytes,seek_bytes flag
	local if=$1
	local of=$2
	local skip=${3:-0}
	local seek=${4:-0}
	local len=${5}
	local BS=${BSIZE:-$((16*1024))}
	local fn=${FUNCNAME[0]}
	local logOpt=${LogOpt:-status=none}

	local ifsize=$(stat -c%s "$if") || return $?
	((skip >= ifsize)) && {
		echo "[$fn:err] skip beyond the EOF of $if" >&2
		return 1
	}
	local alen=$((ifsize-skip))
	len=${len:-$alen}
	((len > alen)) && {
		len=$alen
		echo "[$fn:warn] (skip+len) beyond the EOF of $if" >&2
	}
	if [[ -n "$of" ]]; then touch "$of" || return $?; fi

	local Q R
	Q=$((len/BS))
	R=$((len%BS))
	if [[ -n "$of" ]]; then
		((Q>0)) && dd if="$if" of="$of" bs=${BS}c count=$Q skip=$skip seek=$seek iflag=skip_bytes oflag=seek_bytes conv=notrunc $logOpt
		((R>0)) && dd if="$if" of="$of" bs=${R}c count=1 skip=$((skip+BS*Q)) seek=$((seek+BS*Q)) iflag=skip_bytes oflag=seek_bytes conv=notrunc $logOpt
	else
		((Q>0)) && dd if="$if" bs=${BS}c count=$Q skip=$skip iflag=skip_bytes $logOpt
		((R>0)) && dd if="$if" bs=${R}c count=1 skip=$((skip+BS*Q)) iflag=skip_bytes $logOpt
	fi
}

P=$0
[[ $0 = /* ]] && P=${0##*/}

args=()
for arg; do
	case "$arg" in
	-bs*=*)  BSIZE=${arg/*=/};;
	-s*=*)   SEP=${arg/*=/};;
	-log=*)  LogLevel=${arg/*=/};;
	-ver=*)  _ver=${arg/*=/};;
	-*)      :;;
	*)       args[${#args[@]}]="$arg";;
	esac
done
set -- "${args[@]}"
[[ $# -lt 1 ]] && {
	cat <<-COMM
	Usage: $P <ifile[:skip_offset[:len]]> [ofile[:seek_offset]] [-bs=BS] [-sep=<seperator>] [-log=<0|1|2>]
	#Comment: if 'skip_offset' start with '['; trate it as 'start' #((start=skip_offset+1))
	#Comment: if 'len' has a suffix ']'; trate it as 'end' #((end=skip_offset+len))
	#Comment: e.g: ifile:5:5 <=is equivalent to=> ifile:[6:10]

	Examples:
	  $P ifile:8192:512  ofile
	  $P ifile::4096     ofile:1024
	  $P ifile:4                     #output to stdout
	  $P <(cat):4  ofile             #read from stdin
	  $P ifile::4  ifile:10          #copy data within same file
	  $P ifile:1:9 ifile:6           #copy data within same file overlap

	Tests:
	  echo -n "0123456789abcdef" >a; echo -n "^*******************************" >b
	  $P a::4   b:8;  sed "s/$/\n/" b
	  $P a:3:8  b:8;  sed "s/$/\n/" b
	  $P a:3:12 b:8;  sed "s/$/\n/" b
	  $P a:3:14 b:8;  sed "s/$/\n/" b
	  $P a:3:16 b:8;  sed "s/$/\n/" b
	  $P a:3:16 b:64; sed "s/$/\n/" b
	  $P a::4   a:10; sed "s/$/\n/" a
	  rm -f -- a b
	COMM
	exit 1
}

SEP=${SEP:-:}
IFS=$SEP read if skip len <<<"${1}"
IFS=$SEP read of seek <<<"${2}"
skip=${skip:-0}
seek=${seek:-0}
[[ "$skip" = [* ]] && { skip=${skip:1}; skip=$((skip > 0 ? skip - 1 : 0)); }
[[ "$len" = *] ]] && { len=${len:0:-1}; len=$((len > skip ? len - skip : 0)); }
[[ "$seek" = [* ]] && { seek=${seek:1}; seek=$((seek > 0 ? seek - 1 : 0)); }
Status=${Status:-none}
case "${LogLevel}" in (1) Status=noxfer;; (2) Status=progress;; esac
LogOpt=status=$Status

if [[ "$_ver" = o* ]]; then
	dd_file_range_old "$if" "$of" $skip $seek $len
elif dd --help|grep -q skip_bytes; then
	dd_file_range "$if" "$of" $skip $seek $len
else
	dd_file_range_old "$if" "$of" $skip $seek $len
fi
