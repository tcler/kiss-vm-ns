#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick) gocr and vncdotool

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

. /etc/os-release
OS=$NAME

case ${OS,,} in
red?hat|centos*|rocky*)
	OSV=$(rpm -E %rhel)
	if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

#install gm(GraphicsMagick/ImageMagick)
! which gm 2>/dev/null && ! which convert 2>/dev/null && {
	echo -e "\n{ggv-install} install GraphicsMagick/ImageMagick ..."
	case ${OS,,} in
	fedora*|red?hat*|centos*|rocky*)
		yum $yumOpt install -y GraphicsMagick; which gm 2>/dev/null || yum $yumOpt install -y ImageMagick
		;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y graphicsmagick; which gm 2>/dev/null || apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y imagemagick
		;;
	opensuse*|sles*)
		zypper in --no-recommends -y GraphicsMagick; which gm 2>/dev/null || zypper in --no-recommends -y ImageMagick
		;;
	*)
		: #fixme add more platform
		;;
	esac

	#if still install fail, try install from brew
	! which gm &>/dev/null && ! which convert &>/dev/null && {
		export PATH=/usr/local/bin:$PATH
		which brewinstall.sh 2>/dev/null && brewinstall.sh latest-GraphicsMagick
	}
}

#install gocr
echo
! which gocr 2>/dev/null && {
	echo -e "\n{ggv-install} install gocr ..."

	case ${OS,,} in
	fedora*|red?hat*|centos*|rocky*)
		yum $yumOpt install -y gocr;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y gocr;;
	opensuse*|sles*)
		zypper in --no-recommends -y gocr;;
	*)
		:;; #fixme add more platform
	esac

	which gocr 2>/dev/null || {
		echo -e "\n{ggv-install} install gocr from src ..."
		case ${OS,,} in
		fedora*|red?hat*|centos*|rocky*)
			yum $yumOpt install -y autoconf gcc make netpbm-progs;;
		debian*|ubuntu*)
			apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y autoconf gcc make netpbm;;
		opensuse*|sles*)
			zypper in --no-recommends -y autoconf gcc make netpbm;;
		*)
			:;; #fixme add more platform
		esac

		while true; do
			rm -rf gocr
			_url=https://github.com/tcler/gocr
			while ! git clone --depth=1 $_url; do [[ -d gocr ]] && break || sleep 5; done
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
echo
! which vncdo 2>/dev/null && {
	echo -e "\n{ggv-install} install vncdotool ..."
	WHICH="which --skip-alias --skip-functions"
	case ${OS,,} in
	fedora*|red?hat*|centos*|rocky*)
		yum $yumOpt --setopt=strict=0 install -y python-devel python-pip platform-python-devel python3-pip;;
	debian*|ubuntu*)
		WHICH="which"
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y python-pip python3-pip;;
	opensuse*|sles*)
		zypper in --no-recommends -y python-pip python3-pip;;
	*)
		:;; #fixme add more platform
	esac

	PIP=$($WHICH pip3 2>/dev/null)
	$WHICH pip3 &>/dev/null || PIP=$($WHICH pip 2>/dev/null)
	$PIP --default-timeout=720 install --upgrade pip
	$PIP --default-timeout=720 install --upgrade setuptools
	$PIP --default-timeout=720 install vncdotool service_identity
}
