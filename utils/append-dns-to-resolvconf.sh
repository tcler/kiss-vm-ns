#!/bin/bash

dnsdomain=
dnsaddrs=()
for a; do [[ "$a" != [0-9:]* ]] && dnsdomain=$a || dnsaddrs+=($a); done

resolvConf=/etc/resolv.conf
if grep -q 127.0.0.53 $resolvConf; then
	resolvedConf=/etc/systemd/resolved.conf
	if grep -q ^DNS= $resolvedConf; then
		sed -i "/^DNS=/s/$/${dnsaddrs[@]}/" $resolvedConf
	else
		echo "DNS=${dnsaddrs}" >>$resolvedConf
	fi
	systemctl restart systemd-resolved
else
	echo -e "make_resolv_conf(){\n    :\n}" >/etc/dhclient-enter-hooks
	echo -e "[main]\ndns=none" >/etc/NetworkManager/NetworkManager.conf
	systemctl restart NetworkManager
	mv $resolvConf ${resolvConf}.orig
	{
		grep -E -i "^search.* ${dnsdomain,,}( |$)" ${resolvConf}.orig ||
			sed -n -e "/^search/{s//& ${dnsdomain,,}/; p}" ${resolvConf}.orig
		for nsaddr in "${dnsaddrs[@]}"; do
			grep -E -q "^nameserver $nsaddr" ${resolvConf}.orig ||
				echo "nameserver $nsaddr   #$dnsdomain"
		done
		grep -E ^nameserver ${resolvConf}.orig | grep -v "#$dnsdomain"
	} >$resolvConf
	cat $resolvConf
fi
