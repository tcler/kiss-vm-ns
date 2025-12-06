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
get_br_slaves_by_nmcli() { local if=$1; nmcli -g BRIDGE.SLAVES device show "$if" | sed 's/ /\n/g'; }
detach_slave() { local slave=$1; ip link set $slave nomaster; }

if [[ -n "$brif" ]]; then
	slaves=$(get_br_slaves_by_ip $brif)
fi
for slave in $slaves; do
	echo "{info} detaching slave: $slave from $brif"
	detach_slave $slave
	ifconn=$(nmcli -g GENERAL.CONNECTION device show ${slave})
	[[ ${ifconn} = *slave* ]] && nmcli con delete ${ifconn}
done

if [[ -n "$brconn" ]]; then
	echo "{info} down and remove '$brconn'"
	nmcli connection down "$brconn"
	nmcli connection delete "$brconn"
fi

for ifname in $slaves; do
	ifconn=$(nmcli -g GENERAL.CONNECTION device show ${ifname})
	if [[ -z "${ifconn}" ]]; then
		nmcli con add type ethernet ifname ${slave} con-name ${slave}-conn
	else
		nmcli con up ${ifconn}
	fi
done
