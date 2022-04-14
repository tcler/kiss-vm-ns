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
	install-sbopkg.sh
	sbopkg_install() {
		local pkg=$1
		sudo /usr/sbin/sqg -p $pkg
		yes $'Q\nY\nP\nC' | sudo /usr/sbin/sbopkg -B -i $pkg
	}
	;;
red?hat|centos*|rocky*)
	OSV=$(rpm -E %rhel)
	if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

echo -e "\n{wimlib-install} install wimlib from repo ..."
command -v wiminfo || {
	case ${OS,,} in
	slackware*)
		sbopkg_install wimlib
		;;
	fedora*|red?hat*|centos*|rocky*)
		yum $yumOpt install -y wimlib-utils
		;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y wimtools
		;;
	opensuse*|sles*)
		zypper in --no-recommends -y wimtools
		;;
	*)
		: #fixme add more platform
		;;
	esac

	command -v wiminfo || {
		echo -e "\n{wimlib-install} install wimlib from src ..."
		case ${OS,,} in
		fedora*|red?hat*|centos*|rocky*)
			yum $yumOpt --setopt=strict=0 install -y \
				autoconf git gcc make libxml2-devel fuse fuse-libs fuse-devel fuse3 fuse3-libs fuse3-devel ntfs-3g-devel;;
		debian*|ubuntu*)
			apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y --ignore-missing \
				git autoconf pkg-config gcc make libxml2-dev libfuse-dev ntfs-3g-dev;;
		opensuse*|sles*)
			zypper in --no-recommends -y autoconf git gcc make libxml2-devel fuse-devel libntfs-3g-devel;;
		*)
			:;; #fixme add more platform
		esac

		wimliburl=https://wimlib.net/downloads/wimlib-1.13.5.tar.gz
		tgzf=${wimliburl##*/}
		rm -rf ${tgzf} ${tgzf%.tar.gz}
		wget -4 $wimliburl && tar zxf ${tgzf}
		(cd ${tgzf%.tar.gz} &&
			{ ./configure || ./configure --without-fuse; } &&
			make && make install)
		rm -rf ${tgzf} ${tgzf%.tar.gz}
	}
}

