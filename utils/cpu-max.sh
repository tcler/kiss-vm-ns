#!/bin/bash

LANG=C
sysudir=/sys/devices/system/cpu
uon=($sysudir/cpu0)
uoff=()

for U in $sysudir/cpu[1-9]*; do [[ $(< $U/online) = 1 ]] && uon+=($U) || uoff+=($U); done

ucnt=$((${#uon[@]}+${#uoff[@]}))
uoncnt=$1
[[ -z "${uoncnt}" ]] && { echo "{info} online cpu-cores: ${#uon[@]}/${ucnt}"; exit 0; }

if [[ ${uoncnt} =~ [^0-9] ]]; then
	echo -e "{error} invalide cpu-core number\nUsage: <$0> [cpu-online-number]" >&2
	exit 1
fi
uoncnt=$(($uoncnt+0))

if [[ ${uoncnt} -gt ${ucnt} || ${uoncnt} -lt 0 ]]; then
	echo -e "{warn} cpu number ${uoncnt} should between: [1, $ucnt]" >&2
	exit 1
fi

if [[ $uoncnt -eq ${#uon[@]} ]]; then
	echo "{info} online cpu-core: ${#uon[@]}/${ucnt}, do nothing"
	exit 0
fi

switchroot() {
	local P=$0 SH=; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

#__main__
switchroot "$@"
echo "{info} current online cpu-cores: ${#uon[@]}/${ucnt}"
if [[ $uoncnt -lt ${#uon[@]} ]]; then
	noff=$(( ${#uon[@]} - uoncnt ))
	echo -e "{info} disable $noff cpu-cores ..."
	for _U in ${uon[@]}; do
		[[ "${_U}" = */cpu0 ]] && continue
		echo 0 > ${_U}/online
		((--noff == 0)) && break
	done
elif [[ $uoncnt -gt ${#uon[@]} ]]; then
	non=$(( uoncnt - ${#uon[@]} ))
	echo -e "{info} enable $non cpu-cores ..."
	for _U in ${uoff[@]}; do
		echo 1 > ${_U}/online
		((--non == 0)) && break
	done
fi

uon=($sysudir/cpu0)
uoff=()
for U in $sysudir/cpu[1-9]*; do [[ $(< $U/online) = 1 ]] && uon+=($U) || uoff+=($U); done
echo "{info} updated online cpu-cores: ${#uon[@]}/${ucnt}"
