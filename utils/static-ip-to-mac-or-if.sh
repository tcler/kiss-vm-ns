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
ipaddr=
mac=
ifname=
remac='^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$'
reip='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'

[[ $# -lt 2 ]] && { echo "Usage: $0 <ip-address> <mac-addr|ifname>" >&2; exit 1; }
for arg; do
	if [[ "$arg" =~ ^$reip\.$reip\.$reip\.$reip(/[0-9]+)?$ ]]; then
		ipaddr=$arg
		[[ "$ipaddr" =~ .*/[0-9]+$ ]] || ipaddr+=/24
	elif [[ "$arg" =~ $remac ]]; then
		mac=$arg
	elif [[ -e /sys/class/net/${arg%:} ]]; then
		ifname=${arg%:}
	fi
done
[[ -z "$ipaddr" ]] && { echo "Usage: $0 <ip-address> <mac-addr|ifname>" >&2; exit 2; }

#get ifname by mac-addr
[[ -z "$ifname" && -n "$mac" ]] && {
	for ((i=0;i<8;i++)); do
		ifname=$(ip -o link | awk -F'[ :]+' "/$mac/{print \$2}")
		[[ -z "$ifname" ]] && { sleep 1; } || break
	done
}
[[ -z "$ifname" ]] && { echo "{error} mac-addr($mac) not found" >&2; exit 2; }
[[ -e /sys/class/net/${ifname} ]] || { echo "{error} network interface($ifname) not exist" >&2; exit 2; }

#get connection name by ifname
for ((i=0;i<8;i++)); do
	coname=$(nmcli -g GENERAL.CONNECTION device show ${ifname})
	[[ -z "$coname" ]] && { sleep 1; } || break
done
[[ -z "$coname" ]] && {
	coname=con-${ifname}
	nmcli con add type ethernet ifname ${ifname} con-name $coname
	systemctl restart NetworkManager
}

#assign static-ip to connection/ifname
nmcli con mod "${coname}" ipv4.addresses $ipaddr ipv4.method manual
nmcli con up "${coname}"
