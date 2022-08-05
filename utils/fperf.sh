#!/bin/bash
# yin-jianhong@163.com

export LANG=C
P=${0##*/}
Usage() {
	echo "Usage: $P -f <file> [-t <r|w>] [dd args]"
	echo "  e.g: $P -f /mnt/nfsmp/testfile -t w bs=1M count=20000"
}
_at=`getopt -o hf:t: \
	--long help \
    -n '$P' -- "$@"`
eval set -- "$_at"

testf=
iotype=r
while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-f)		testf=$2; shift 2;;
	-t)		iotype=$2; shift 2;;
	--) shift; break;;
	esac
done
ddargs="$*"

[[ -z "$testf" ]] && {
	Usage >&2
	exit 1
}

case $iotype in
r*|R*)
	#[[ -n "$testf" && -f "$testf" && -r "$testf" ]] || {
	[[ -n "$testf" && -r "$testf" ]] || {
		echo "'$testf' is not a regular file or no read permission" >&2
		exit 1
	}

	[[ -z "$ddargs" && "$testf" =~ ^/dev/ ]] && ddargs="bs=1M count=500"
	ddinfo=$(LANG=C dd if="$testf"  of=/dev/null $ddargs 2>&1)
	read B _a _b _c _d S _y _z < <(echo "$ddinfo" | tail -n1)
	[[ $S = [0-9]* ]] ||
		read B _a _b _c _d _e _f S _y _z < <(echo "$ddinfo" | tail -n1)
	;;
*)
	[[ -f "$testf" ]] && {
		echo "file '$testf' exist, will cover it" >&2
		read -t 5 aws
	}

	[[ -f "$testf" ]] || rmflag=1
	[[ -z "$ddargs" ]] && ddargs="bs=1M count=500"

	ddinfo=$(LANG=C dd if=/dev/zero  of="$testf" $ddargs 2>&1)
	read B _a _b _c _d S _y _z < <(echo "$ddinfo" | tail -n1)
	[[ $S = [0-9]* ]] ||
		read B _a _b _c _d _e _f S _y _z < <(echo "$ddinfo" | tail -n1)

	[[ "$rmflag" == 1 ]] && rm -f "$testf"
	;;
esac

echo "$ddinfo" >&2
awk "BEGIN{print int($B/$S)}"

