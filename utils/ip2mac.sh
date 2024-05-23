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

[[ -z "$ipaddr" || -z "$mac" ]] && {
	echo "Usage: $0 <ip-address> <mac-addr>" >&2
	exit 1
}

[[ "$ipaddr" =~ .*/[0=9]+$ ]] || ipaddr+=/24

ifname_=$(ip -o link | awk "/$mac/{print \$2}")
coname=$(nmcli -g GENERAL.CONNECTION device show ${ifname_%:})
nmcli con mod "${coname}" ipv4.addresses $ipaddr
