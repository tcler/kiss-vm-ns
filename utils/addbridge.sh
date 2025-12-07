#!/bin/bash

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

is_bridge() { local ifname=$1; ip -d a s "$ifname" | grep -qw bridge; }
is_wireless() { local ifname=$1; test -d /sys/class/net/$ifname/wireless; }
is_slave() {
	local ifname=$1
	read key br < <(ip addr show dev $ifname | grep -Eo 'master [^ ]+')
	echo $br
	[[ -n "$br" ]] && return 0 || return 1
}

#__main__
switchroot "$@"

Usage() {
	cat <<-USAGE | GREP_COLORS='ms=01;35' grep --color .
	Usage: $0 [bridge name] [bridge-slave ifname] [-f] [-ni]
	Comment:
	  if [bridge-slave ifname] is omitted, use the default route's interface as the default.
	  if [bridge name] is omitted, use use 'br0' by default
	Options:
	  -f force  #if the bridge-slave is also a bridge device, force the action
	  -ni non-interactive mode, will not ask user to confirm
	USAGE
}

force=no
interactive=yes
_at=()
for arg; do
	case $arg in
	-f) force=yes;;
	-ni) interactive=no;;
	*) _at+=("$arg");;
	esac
done
set -- "${_at[@]}"
brname=${1}
ifname=${2}

brname=${brname:-br0}
[[ -z "$ifname" ]] && ifname=$(get-default-if.sh)
[[ -z "$ifname" ]] && {
	echo "{warn} there is no bridge-slave ifname specified, and auto detect fail." >&2
	Usage >&2
	exit 1
}

brop=create
if ip addr show dev $brname &>/dev/null; then
	echo "{warn} bridge dev '$brname' has been there, keep it" >&2
	ip -br link show master "$brname" >&2
	brop=keep
fi
if br=$(is_slave $ifname); then
	echo "{warn} network interface '$ifname' has been a bridge-slave of '$br'" >&2
	Usage >&2
	exit 1
fi

if [[ $ifname = $brname ]]; then
	echo "{warn} now the default route interface is just $brname, see the usage:" >&2
	Usage >&2
	exit 1
fi
if is_bridge $ifname && [[ "$force" != yes ]]; then
	echo "{warn} network interface '$ifname' is bridge device, add -f option if you really want nested bridge device!" >&2
	exit 1
fi

if is_wireless $ifname && [[ "$force" != yes ]]; then
	echo "{warn} network interface '$ifname' is wifi, add -f option if you really want try to add wireless dev to bridge!" >&2
	exit 1
fi

echo "{info} will $brop bridge '$brname' and add '$ifname' in it as bridge-slave."
if [[ $interactive = yes ]]; then
	read -p "Add it might cause network connection break. Are you sure?(Y/N): " answer
	if [[ "$answer" != [Yy]* ]]; then
	    echo "OK, let's quit"
	    exit 0
	fi
fi

#remove if connection
ifconname=$(nmcli -g GENERAL.CONNECTION device show $ifname)
nmcli c delete "$ifconname" &>/dev/null

#create br connection
if [[ $brop = create ]]; then
	nmcli c add type bridge ifname $brname stp on forward-delay 2 autoconnect yes
else
	brconname=$(nmcli -g GENERAL.CONNECTION device show $brname)
	[[ -z "$brconname" ]] &&
		nmcli c add type bridge ifname $brname stp on forward-delay 2 autoconnect yes
fi

brconname=$(nmcli -g GENERAL.CONNECTION device show $brname)
if is_wireless $ifname; then
	echo "{info} enable proxy_arp, because '$ifname' is a wireless dev" >&2
	sysctlf=/etc/sysctl.d/100-kissvm-proxy-arp.conf
	for nic in $ifname $brname; do
		echo "net.ipv4.conf.${nic}.proxy_arp = 1"
	done | tee $sysctlf
	sysctl -p $sysctlf

	#ip link set dev $brname up
	#ip link set dev $ifname up
	#ip link set $ifname master $brname   #most wireless can not be added to bridge
	cat <<-EOF >&2
	{warn} trying add wireless into bridge, it might be fail, and it's expected, you can try:
	  sudo ip link set $ifname master $brname
	to get the warn/error message show why it does not work.
	EOF
fi

#create slave if connection and add to bridge
slave_conname=bridge-slave-$ifname
nmcli c delete "$slave_conname" 2>/dev/null
nmcli c add type bridge-slave ifname "$ifname" master "$brname" autoconnect yes con-name "$slave_conname"
nmcli con up $brconname

systemctl restart NetworkManager
sleep 0.5
#show slaves in br
ip -br link show master "$brname"
