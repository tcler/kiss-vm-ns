#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick) gocr and vncdotool

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

OSV=$(rpm -E %rhel)
if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
	if [[ "$OSV" != "%rhel" ]]; then
		yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
fi

#install gm(GraphicsMagick/ImageMagick)
! which gm &>/dev/null && ! which convert &>/dev/null && {
	echo -e "\n{ggv-install} install GraphicsMagick/ImageMagick ..."
	yum $yumOpt install -y GraphicsMagick; which gm 2>/dev/null || yum $yumOpt install -y ImageMagick

	#if still install fail, try install from brew
	! which gm &>/dev/null && ! which convert &>/dev/null && {
		export PATH=/usr/local/bin:$PATH
		which brewinstall.sh 2>/dev/null && brewinstall.sh latest-GraphicsMagick
	}
}

#install gocr
! which gocr &>/dev/null && {
	echo -e "\n{ggv-install} install gocr ..."
	yum $yumOpt install -y gocr; which gocr 2>/dev/null || {
		echo -e "\n{ggv-install} install gocr from src ..."
		yum install -y autoconf gcc make netpbm-progs
		while true; do
			rm -rf gocr
			git clone https://github.com/tcler/gocr
			(
			cd gocr
			./configure --prefix=/usr && make && make install
			)
			which gocr && break

			sleep 5
			echo -e " {ggv-install} installing gocr fail, try again ..."
		done
	}
}

#install vncdotool
! which vncdo &>/dev/null && {
	echo -e "\n{ggv-install} install vncdotool ..."
	yum $yumOpt install -y python-devel python-pip platform-python-devel python3-pip --setopt=strict=0
	PIP=$(which --skip-alias --skip functions pip 2>/dev/null)
	which pip &>/dev/null || PIP=$(which --skip-alias --skip functions pip3 2>/dev/null)
	$PIP --default-timeout=720 install --upgrade pip
	$PIP --default-timeout=720 install --upgrade setuptools
	$PIP --default-timeout=720 install vncdotool service_identity
}
