#!/bin/bash

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
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
elif command -v pacman; then
	pacman -Sy --noconfirm frr
fi

command -v systemctl && {
	systemctl enable frr
	systemctl start frr
}
