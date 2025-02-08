#!/bin/bash

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

is_bridge() { local ifname=$1; ip -d a s "$ifname" | grep -qw bridge; }
is_slave() {
	local ifname=$1
	read key br < <(ip addr show dev $ifname | grep -Eo 'master [^ ]+')
	echo $br
	[[ -n "$br" ]] && return 0 || return 1
}

#__main__
switchroot "$@"

_at=()
for arg; do [[ "$arg" = -f ]] && force=yes || _at+=("$arg"); done
set -- "${_at[@]}"
brname=${1}
ifname=${2}

brname=${brname:-br0}
[[ -z "$ifname" ]] && ifname=$(get-default-if.sh)
[[ -z "$ifname" ]] && {
	echo "{warn} there is no bridge-slave ifname specified, and auto detect fail." >&2
	echo "{info} Usage: $0 [bridge name] [bridge-slave ifname]" >&2
	exit 1
}

if ip addr show dev $brname &>/dev/null; then
	echo "{warn} bridge dev '$brname' has been there" >&2
	exit 1
fi
if br=$(is_slave $ifname); then
	echo "{warn} network interface '$ifname' has been a bridge-slave of '$br'" >&2
	exit 1
fi
if is_bridge $ifname && [[ "$force" != yes ]]; then
	echo "{warn} network interface '$ifname' is bridge device, add -f option if you really want nested bridge device?" >&2
	exit 1
fi

coname=$(nmcli -g GENERAL.CONNECTION device show $ifname)
nmcli c delete "$coname" 2>/dev/null
nmcli c add type bridge ifname $brname stp off autoconnect yes
nmcli c add type bridge-slave ifname "$ifname" master $brname autoconnect yes

systemctl restart NetworkManager
