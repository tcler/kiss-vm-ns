#!/bin/bash
# author jiyin@redhat.com

P=${0##*/}
#===============================================================================
# get ip addr
get_ip() {
	local ret
	local nic=$1
	local ver=$2
	local sc=${3}
	local ipaddr=$(ip addr show $nic)
	[[ -z "$nic" || -z "$ipaddr" ]] && {
		echo "Usage: $0 <NIC> [4|6|6nfs] [global|link]" >&2
		return 2
	}

	[[ -z "$sc" ]] && {
		sc=global;
		echo "$ipaddr"|grep -q 'inet6.*global' || sc=link;
	}
	local flg='(global|host lo)'

	case $ver in
	6|6nfs)
		ret=$(echo "$ipaddr" | awk '/inet6.*'"$sc"'/{match($0,"inet6 ([0-9a-f:]+)",M); print M[1]}')
		[[ -n "$ret" && $ver = 6nfs ]] && ret=$ret%$nic
		;;
	4|*)
		ret=$(echo "$ipaddr" | awk '/inet .*'"$flg"'/{match($0,"inet ([0-9.]+)",M); print M[1]}')
		;;
	esac

	echo "$ret"
	[[ -z "$ret" ]] && return 1 || return 0
}

get_default_nic() {
	local ifs=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1];}')
	for iface in $ifs; do
		[[ -z "$(ip -d link show  dev $iface|sed -n 3p)" ]] && {
			break
		}
	done
	echo $iface
}

get_default_ip() {
	local nic=$(get_default_nic)
	[[ -z "$nic" ]] && return 1

	get_ip "$nic" "$@"
}

_P=${P%.sh}
funname=${_P//-/_}
case ${funname} in
get_ip)
	${funname} "$@"
	;;
get_default_nic|get_default_if)
	${funname} "$@"
	;;
get_default_ip)
	${funname} "$@"
	;;
*)
	ip -o addr | awk '!/^[0-9]*: ?lo|link\// {gsub("/", " "); print $2" "$4}'
	;;
esac

