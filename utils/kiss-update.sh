#!/usr/bin/env bash

P=$0; [[ $0 = /* ]] && P=${0##*/}
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P $@" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "$@"
	}
}
switchroot

. /etc/os-release
OS=$NAME
{ command -v git && command -v gmake; } >/dev/null ||
case ${OS,,} in
slackware*)
	/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off git make
	;;
fedora*|red?hat*|centos*|rocky*)
	yum $yumOpt install -y git make
	;;
debian*|ubuntu*)
	apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y git make
	;;
opensuse*|sles*)
	zypper in --no-recommends -y git make
	;;
*)
	exit
	echo "[Error] not supported platform($OS)"
	;;
esac

_repon=kiss-vm-ns
_confdir=/etc/$_repon

install_kiss_tools() {
	local url=https://github.com/tcler/$_repon
	local clonedir=$(mktemp -d)
	git clone $url $clonedir
	gmake -C $clonedir i
	rm -rf $clonedir
}

tmpf=$(mktemp)
wget -qO- http://api.github.com/repos/tcler/$_repon/commits/master -O $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
else
	echo "[Info] found new version, installing ..."
	install_kiss_tools
fi
rm -f $tmpf
