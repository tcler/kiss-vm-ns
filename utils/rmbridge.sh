#!/bin/bash

Usage() {
	cat <<-EOF
	Usage: $0 <bridge-connection|bridge-interface>

	#you could get available bridge-connections by running:
	  nmcli connection show | grep bridge
	EOF
}
if [[ $# -ne 1 ]]; then
	Usage >&2
	exit 1
fi

bridge="$1"
brconn=""
brif=""

is_bridge_conn() { local conn=$1; test bridge = "$(nmcli -g connection.type c s "$conn" 2>/dev/null)"; }
is_bridge_dev() { local ifname=$1; ip -d a s "$ifname" 2>/dev/null | grep -qw bridge; }

# check if $bridge is connection or ifterface name
if is_bridge_conn "$bridge"; then
	brconn="$bridge"
	brif=$(nmcli -g connection.interface-name c s "$brconn")
elif is_bridge_dev $bridge; then
	brif="$bridge"
	brconn=$(nmcli -g GENERAL.CONNECTION device show ${brif})
else
	echo "{Error} '$bridge' is not a valid bridge connection or interface" >&2
	Usage >&2
	exit 1
fi

get_br_slaves_by_ip() { local if=$1; ip -br link show master "$if" | awk '{print $1}'; }
get_br_slaves_by_nmcli() { local if=$1; nmcli -f BRIDGE.SLAVES device show "$if" | awk '{print $2}'; }
detach_slave() { local slave=$1; ip link set $slave nomaster; }

if [[ -n "$brif" ]]; then
	for slave in $(get_br_slaves_by_ip $brif); do
		echo "{info} detaching slave: $slave from $brif"
		detach_slave $slave
	done
fi

if [[ -n "$brconn" ]]; then
	echo "{info} down and remove '$brconn'"
	nmcli connection down "$brconn"
	nmcli connection delete "$brconn"
fi
