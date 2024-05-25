#!/bin/bash

switchroot() {
	local P=$0 SH=; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

#workaround for that no nameserver in /etc/resolv.conf
grep -q ^nameserver /etc/resolv.conf || ip r|awk '/^default/{print "nameserver", $3}' >>/etc/resolv.conf

FRRVER=${FRRVER:-frr-stable}
if command -v yum; then
	verx=$(rpm -E %rhel)
	#since RHEL-8, RHEL has provided frr package by default
	if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
		frrRepoRpmUrl=https://rpm.frrouting.org/repo/$FRRVER-repo-1-0.el${verx}.noarch.rpm
		yum install -y $frrRepoRpmUrl  #${FRRVER}*
	fi
	yum install --setopt=strict=0 -y frr frr-pythontools
elif command -v apt; then
	apt install -y frr
elif command -v zypper; then
	zypper in --no-recommends -y frr
fi

command -v systemctl && {
	systemctl enable frr
	systemctl start frr
}
