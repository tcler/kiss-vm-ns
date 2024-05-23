#!/bin/bash

#workaround for that no nameserver in /etc/resolv.conf
grep -q ^nameserver /etc/resolv.conf || ip r|awk '/^default/{print "nameserver", $3}' >>/etc/resolv.conf

FRRVER=${FRRVER:-frr-stable}
if command -v yum; then
	verx=$(rpm -E %rhel)
	#since RHEL-8, RHEL has provided frr package by default
	if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
		frrRepoRpmUrl=https://rpm.frrouting.org/repo/$FRRVER-repo-1-0.el${verx}.noarch.rpm
		sudo yum install -y $frrRepoRpmUrl  #${FRRVER}*
	fi
	sudo yum install --setopt=strict=0 -y frr frr-pythontools
	systemctl enable frr; systemctl start frr
fi
