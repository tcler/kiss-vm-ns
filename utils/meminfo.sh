#!/bin/bash
#

LANG=C
shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

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
switchroot "$@"

by=lshw
[[ -n "$1" && "$1" != ls* ]] && by=dmidecode
case $by in
ls*)  meminfo_by_lshw || meminfo_by_dmidecode;;
dmi*) meminfo_by_dmidecode || meminfo_by_lshw;;
*)    meminfo_by_lshw || meminfo_by_dmidecode;;
esac || echo "{WARN} package lshw or dmidecode is needed, please install one of all of them first."
