#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick)

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

. /etc/os-release
OSFamily=${ID_LIKE:-${ID}}

case ${OSFamily} in
slackware*)
	sbopkg-install.sh
	sbopkg_install() {
		local pkg=$1
		sudo /usr/sbin/sqg -p $pkg
		yes $'Q\nY\nP\nC' | sudo /usr/sbin/sbopkg -B -i $pkg
	}
	;;
rhel*|centos*|fedora*)
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

echo -e "\n{wimlib-install} install wimlib from repo ..."
command -v wiminfo || {
	case ${OSFamily} in
	slackware*)
		sbopkg_install wimlib
		;;
	fedora*|rhel*|centos*)
		yum $yumOpt install -y wimlib-utils || yum-install-from-fedora.sh wimlib-utils
		;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y wimtools
		;;
	suse*|opensuse*)
		zypper in --no-recommends -y wimtools
		;;
	arch*|archlinux*)
		pacman -Sy --noconfirm wimlib
		;;
	*)
		: #fixme add more platform
		;;
	esac

	command -v wiminfo || {
		echo -e "\n{wimlib-install} install wimlib from src ..."
		case ${OS,,} in
		fedora*|rhel*|centos*)
			yum $yumOpt --setopt=strict=0 install -y \
				autoconf git gcc make libxml2-devel fuse fuse-libs fuse-devel fuse3 fuse3-libs fuse3-devel ntfs-3g-devel;;
		debian*|ubuntu*)
			apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y --ignore-missing \
				git autoconf pkg-config gcc make libxml2-dev libfuse-dev ntfs-3g-dev;;
		suse*|opensuse*)
			zypper in --no-recommends -y autoconf git gcc make libxml2-devel fuse-devel libntfs-3g-devel;;
		arch*|archlinux)
			pacman -Sy --noconfirm autoconf git gcc make libxml2 fuse ntfs-3g;;
		*)
			:;; #fixme add more platform
		esac

		wimliburl=https://wimlib.net/downloads/wimlib-1.13.5.tar.gz
		tgzf=${wimliburl##*/}
		rm -rf ${tgzf} ${tgzf%.tar.gz}
		curl -Ls -4 $wimliburl -o ${tgzf} && tar zxf ${tgzf}
		(cd ${tgzf%.tar.gz} &&
			{ ./configure || ./configure --without-fuse; } &&
			make && make install)
		rm -rf ${tgzf} ${tgzf%.tar.gz}
	}
}

