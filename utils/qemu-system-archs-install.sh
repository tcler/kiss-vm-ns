#!/bin/bash
# this script is used to install qemu-system-${arch}

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

#install qemu-system-*
#archlist=$(yum search qemu-system- | sed -n '/^qemu-system-/ {s///; s/.x86_64.*$//; p}' | grep -v core)
archlist="$*"
[[ -z "$archlist" ]] && archlist="aarch64 riscv ppc s390x"
pkglist=$(printf "qemu-system-%s " $archlist)
case ${OS,,} in
slackware*)
	/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install $pkglist
	;;
fedora*|red?hat*|centos*|rocky*)
	yum $yumOpt install -y $pkglist
	yum $yumOpt install -y qemu-device-display-virtio-gpu-ccw
	;;
debian*|ubuntu*)
	apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y $pkglist
	;;
opensuse*|sles*)
	zypper in --no-recommends -y $pkglist
	;;
*)
	: #fixme add more platform
	;;
esac
