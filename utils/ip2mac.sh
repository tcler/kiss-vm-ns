#!/bin/bash

switchroot() {
	local P=$0 SH=; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

#__main__
switchroot "$@"

_at=()
for arg; do [[ "$arg" = -f ]] && force=yes || _at+=("$arg"); done
set -- "${_at[@]}"
ipaddr=${1}
mac=${2}
remac='^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$'
reip='^([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'

[[ -z "$ipaddr" || -z "$mac" ]] && {
	echo "Usage: $0 <ip-address> <mac-addr>" >&2
	exit 1
}
[[ "$ipaddr" =~ $remac && "$mac" =~ $reip ]] && read ipaddr mac <<<"$mac $ipaddr"
[[ "$ipaddr" =~ .*/[0-9]+$ ]] || ipaddr+=/24

for ((i=0;i<8;i++)); do
	ifname=$(ip -o link | awk -F'[ :]+' "/$mac/{print \$2}")
	[[ -z "$ifname" ]] && sleep 2 || break
done
[[ -z "$ifname" ]] && { echo "mac-addr($mac) not found" >&2; exit 2; }

for ((i=0;i<16;i++)); do
	coname=$(nmcli -g GENERAL.CONNECTION device show ${ifname})
	[[ -z "$coname" ]] && sleep 2 || break
done
[[ -z "$coname" ]] && { coname=con-${ifname}; nmcli con add type ethernet ifname ${ifname} con-name $coname; }
nmcli con mod "${coname}" ipv4.addresses $ipaddr ipv4.method manual
nmcli con up "${coname}"
