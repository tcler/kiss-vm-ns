#!/bin/bash

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

#install packages required
yum install -y python-devel platform-python-devel python-pip python3-pip --setopt=strict=0
PIP=$(which --skip-alias --skip functions pip 2>/dev/null)
which pip &>/dev/null || PIP=$(which --skip-alias --skip functions pip3 2>/dev/null)

$PIP --default-timeout=720 install --upgrade pip
$PIP --default-timeout=720 install --upgrade setuptools
$PIP --default-timeout=720 install vncdotool service_identity
