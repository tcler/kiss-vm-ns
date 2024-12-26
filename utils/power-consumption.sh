#!/bin/bash
#ref: https://www.baeldung.com/linux/power-consumption

switchroot() {
	local P=$0 SH=; [[ -x $0 && $0 = /* ]] && command -v ${0##*/} &>/dev/null && P=${0##*/}; [[ ! -f $P || ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		if [[ "${SHELL##*/}" = $P ]]; then
			echo -e "\E[1;31m{WARN} $P need root permission, please add sudo before $P\E[0m" >&2
			exit
		else
			echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m" >&2
			exec sudo $SH $P "$@"
		fi
	}
}
switchroot "$@"

time=${1:-8}
ZN=($(sudo cat /sys/class/powercap/*/name))      #Name of the power zone
E0=($(sudo cat /sys/class/powercap/*/energy_uj)) #energy counter in micro joules at time A
sleep $time;
E1=($(sudo cat /sys/class/powercap/*/energy_uj)) #energy counter in micro joules at time A + $time

for i in "${!E0[@]}"; do
	awk -v ZN=${ZN[i]} -v E1=${E1[i]} -v E0=${E0[i]} -v time=$time 'BEGIN { printf "%s: %.1f W\n", ZN, (E1-E0) / time / 1e6 }'
done
