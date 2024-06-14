#!/bin/bash
# author jiyin@redhat.com

P=${0##*/}
#===============================================================================
# get ip addr
get_ip() {
	local ret= ipaddr= masklen= with_mask= _at=()
	for arg; do [[ "$arg" = -m ]] && with_mask=yes || _at+=("$arg"); done
	set -- "${_at[@]}"
	local nic=$1
	local ver=$2
	local sc=${3}
	local ipaddr=$(ip addr show $nic)
	[[ -z "$nic" || -z "$ipaddr" ]] && {
		echo "Usage: $0 [-m] <NIC> [4|6|6nfs] [global|link]" >&2
		return 2
	}

	[[ -z "$sc" ]] && {
		sc=global;
		echo "$ipaddr"|grep -q 'inet6.*global' || sc=link;
	}
	local flg='(global|host lo)'

	case $ver in
	6|6nfs)
		IFS=/ read ipaddr masklen < <(echo "$ipaddr" | awk '/inet6.*'"$sc"'/{match($0,"inet6 ([0-9a-f:]+/[0-9]+)",M); print M[1]}')
		ret=$ipaddr/$masklen; [[ -n "$ret" && $ver = 6nfs ]] && ret=$ret%$nic
		;;
	4|*)
		IFS=/ read ipaddr masklen < <(echo "$ipaddr" | awk '/inet .*'"$flg"'/{match($0,"inet ([0-9.]+/[0-9]+)",M); print M[1]}')
		ret=$ipaddr/$masklen
		;;
	esac

	[[ "$with_mask" != yes ]] && ret=${ret/\/${masklen}/}
	echo "${ret}"
	[[ -z "$ret" ]] && return 1 || return 0
}

is_bridge() {
	local ifname=$1
	[[ -z "$ifname" ]] && return 1
	LANG=C ip -d a s $ifname | grep -qw bridge
}

get_default_if() {
	local notbr=$1  #indicate get real NIC not bridge
	local _iface= iface=
	local type=

	ifaces=$(ip route | awk '/^default/{print $5}')
	for _iface in $ifaces; do
		type=$(ip -d link show dev $_iface|sed -n '3{s/^\s*//; p}')
		[[ -z "$type" || "$type" = altname* || "$type" = bridge* ]] && {
			iface=$_iface
			break
		}
	done
	if [[ -n "$notbr" ]] && is_bridge $iface; then
		# ls /sys/class/net/$iface/brif
		if command -v brctl >/dev/null; then
			brctl show $iface | awk 'NR==2 {print $4}'
		else
			ip link show type bridge_slave | awk -F'[ :]+' '/master '$iface' state UP/{print $2}' | head -n1
		fi
		return 0
	fi
	echo $iface
}

: <<\COMM
get_default_nic() {
	local ifs=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1];}')
	for iface in $ifs; do
		[[ -z "$(ip -d link show  dev $iface|sed -n 3p)" ]] && {
			break
		}
	done
	echo $iface
}
COMM
get_default_nic() { get_default_if "$@"; }

get_default_ip() {
	local nic=$(get_default_if)
	[[ -z "$nic" ]] && return 1

	get_ip "$nic" "$@"
}

get_default_netaddr() {
	local nic=$(get_default_if)
	[[ -z "$nic" ]] && return 1

	get_net_addr -m $(get_ip "$nic" -m)
}

get_default_gateway() { ip route show | awk '$1=="default"{print $3; exit}'; }

_get_ipcalc() { IPCALC=ipcalc; command -v ipcalc-ng &>/dev/null && IPCALC=ipcalc-ng; }
get_net_mask() {
	[[ $# = 0 ]] && { echo "Usage: $0 <ip4>" >&2; return 1; }
	local ip4="$1";
	_get_ipcalc
	$IPCALC $ip4 | awk '/Netmask:/{print $2}';
}
get_net_addr() {
	[[ $# = 0 ]] && { echo "Usage: $0 <ip4/masklen>" >&2; return 1; }
	local with_mask= ip4=
	for arg; do [[ "$arg" = -m ]] && with_mask=yes || _at+=("$arg"); done
	set -- "${_at[@]}"
	ip4="$1"
	_get_ipcalc

	if [[ "$with_mask" = yes ]]; then
		$IPCALC $ip4 | awk '/Network:/{print $2}';
	else
		$IPCALC $ip4 | awk -F'[[:space:]/]+' '/Network:/{print $2}';
	fi
}
get_if_by_ip() {
	[[ $# = 0 ]] && { echo "Usage: $0 <ip4|ip6>" >&2; return 1; }
	local ipaddr="${1%%/*}"
	ip -br a sh | awk -v pat=${ipaddr}/ '$0 ~ pat {print $1}'
}

_P=${P%.sh}
funname=${_P//-/_}
case ${funname} in
get_ip|get_default_nic|get_default_if|get_default_ip|get_default_netaddr|get_default_gateway|get_net_mask|get_net_addr|get_if_by_ip)
	${funname} "$@"
	;;
*)
	ip -o addr | awk '!/^[0-9]*: ?lo|link\// {gsub("/", " "); print $2" "$4}'
	;;
esac
