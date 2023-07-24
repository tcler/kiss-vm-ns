#!/usr/bin/env bash
{
switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

. /etc/os-release
OS=$NAME
{ command -v git && command -v gmake; } >/dev/null ||
case ${OS,,} in
slackware*)
	/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off git make
	;;
fedora*|red?hat*|centos*|rocky*|anolis*)
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
	for ((i=0;i<8;i++)); do git clone --depth=1 $url $clonedir && break || sleep 2; done
	gmake -C $clonedir i
	rm -rf $clonedir
}

tmpf=$(mktemp)
cleanup() { rm -rf $tmp; }
trap cleanup SIGINT SIGQUIT SIGTERM
curl -Ls http://api.github.com/repos/tcler/$_repon/commits/master -o $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
else
	echo "[Info] found new version, installing ..."
	install_kiss_tools
fi
rm -f $tmpf
exit
}
