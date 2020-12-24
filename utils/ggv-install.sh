#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick) gocr and vncdotool

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
	OSV=$(rpm -E %rhel)
	if [[ "$OSV" != "%rhel" ]]; then
		yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
fi

#install gm(GraphicsMagick/ImageMagick)
! which gm &>/dev/null && ! which convert &>/dev/null && {
	yum $yumOpt install -y GraphicsMagick; which gm 2>/dev/null || yum $yumOpt install -y ImageMagick
}

#install gocr
! which gocr &>/dev/null && {
	yum $yumOpt install -y gocr; which gocr 2>/dev/null || {
		yum install -y autoconf gcc make netpbm-progs
		git clone https://github.com/tcler/gocr
		(
		cd gocr
		./configure && make && make install
		)
	}
}

#install vncdotool
! which vncdo &>/dev/null && {
	yum $yumOpt install -y python-devel python-pip platform-python-devel python3-pip --setopt=strict=0
	PIP=$(which --skip-alias --skip functions pip 2>/dev/null)
	which pip &>/dev/null || PIP=$(which --skip-alias --skip functions pip3 2>/dev/null)
	$PIP --default-timeout=720 install --upgrade pip
	$PIP --default-timeout=720 install --upgrade setuptools
	$PIP --default-timeout=720 install vncdotool service_identity
}
