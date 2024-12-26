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

time=${1:-1}
T0=($(sudo cat /sys/class/powercap/*/energy_uj))
sleep $time;
T1=($(sudo cat /sys/class/powercap/*/energy_uj))

for i in "${!T0[@]}"; do
	awk -v T1=${T1[$i]} -v T0=${T0[$i]} -v time=$time 'BEGIN { printf "%.1f W\n", (T1-T0) / time / 1e6 }'
done
