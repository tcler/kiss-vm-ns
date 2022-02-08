#!/bin/sh

if command -v sysctl; then
	sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
else
	sudo bash -c 'echo 1 >/proc/sys/net/ipv6/conf/all/disable_ipv6'
fi
