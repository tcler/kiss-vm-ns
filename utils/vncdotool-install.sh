#!/bin/bash

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

#install epel repo
if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
	OSV=$(rpm -E %rhel)
	if [[ "$OSV" != "%rhel" ]]; then
		yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
fi

#install packages required
yum install -y python-devel platform-python-devel python-pip python3-pip --setopt=strict=0
PIP=$(which --skip-alias --skip functions pip 2>/dev/null)
which pip &>/dev/null || PIP=$(which --skip-alias --skip functions pip3 2>/dev/null)

$PIP --default-timeout=720 install --upgrade pip
$PIP --default-timeout=720 install --upgrade setuptools
$PIP --default-timeout=720 install vncdotool service_identity
