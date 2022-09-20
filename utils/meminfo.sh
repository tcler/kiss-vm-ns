#!/bin/bash
#

LANG=C
P=$0; [[ $0 = /* ]] && P=${0##*/}; AT=("$@")
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P ${AT[@]}" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "${AT[@]}"
	}
}

meminfo_by_dmidecode() {
	local cmd=dmidecode
	if command -v $cmd; then
		sudo $cmd --type 17;
	else
		return 2;
	fi
}
meminfo_by_lshw() {
	local cmd=lshw
	if command -v $cmd; then
		echo '/\*-memory$/,/*-cache/-1 p'|ed -s <(sudo $cmd);
	else
		return 2;
	fi
}

#__main__
switchroot

by=lshw
[[ -n "$1" && "$1" != ls* ]] && by=dmidecode
case $by in
ls*)  meminfo_by_lshw || meminfo_by_dmidecode;;
dmi*) meminfo_by_dmidecode || meminfo_by_lshw;;
*)    meminfo_by_lshw || meminfo_by_dmidecode;;
esac || echo "{WARN} package lshw or dmidecode is needed, please install one of all of them first."
