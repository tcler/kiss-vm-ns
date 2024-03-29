#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick)

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

. /etc/os-release
OS=$NAME

case ${OS,,} in
slackware*)
	sbopkg-install.sh
	sbopkg_install() {
		local pkg=$1
		sudo /usr/sbin/sqg -p $pkg
		yes $'Q\nY\nP\nC' | sudo /usr/sbin/sbopkg -B -i $pkg
	}
	;;
red?hat|centos*|rocky*|alma*|anolis*)
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

#install netpbm/netpbm-progs or gm(GraphicsMagick/ImageMagick)
! command -v gm && ! command -v convert && {
	case ${OS,,} in
	slackware*)
		/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install imagemagick
		;;
	fedora*|red?hat*|centos*|rocky*|alma*|anolis*)
		yum $yumOpt install -y GraphicsMagick; command -v gm || yum $yumOpt install -y ImageMagick
		;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y graphicsmagick; command -v gm || apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y imagemagick
		;;
	opensuse*|sles*)
		zypper in --no-recommends -y GraphicsMagick; command -v gm || zypper in --no-recommends -y ImageMagick
		;;
	arch?linux)
		pacman -Sy --noconfirm graphicsmagick
		;;
	*)
		: #fixme add more platform
		;;
	esac
}
