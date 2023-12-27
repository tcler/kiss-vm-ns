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

is_available_url() { curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail "$1" &>/dev/null; }
is_rh_intranet() { host ipa.corp.redhat.com &>/dev/null; }
is_rh_intranet() { grep -q redhat.com /etc/resolv.conf; }

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
	local url=https://github.com/tcler/${_repon}/archive/refs/heads/master.tar.gz
	local tmpdir=$(mktemp -d)
	curl -k -Ls $url | tar zxf - -C $tmpdir && gmake -C $tmpdir/${_repon}-master
	rm -rf $tmpdir
	test -f ~/.config/kiss-vm/kiss-vm -o -f ~/.config/kiss-vm-ns/kiss-vm && vm prepare -f
	vm netls | grep -qw kissaltnet ||
		vm netcreate netname=kissaltnet brname=virbr-kissalt subnet=10.172.192.0 domain=alt.kissvm.net
}

tmpf=$(mktemp)
cleanup() { rm -rf $tmp; }
trap cleanup SIGINT SIGQUIT SIGTERM

is_rh_intranet && export https_proxy=squid.redhat.com:8080
curl -Ls http://api.github.com/repos/tcler/$_repon/commits/master -o $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
	if ! cmp /etc/os-release $_confdir/os-release 2>/dev/null; then
		test -f ~/.config/kiss-vm/kiss-vm -o -f ~/.config/kiss-vm-ns/kiss-vm && {
			echo "[Info] exec vm-prepare again, because you os-version has been updated."
			vm prepare -f
		}
	fi
else
	echo "[Info] found new version, installing ..."
	install_kiss_tools
fi
rm -f $tmpf
for d in /var/lib/kiss-vm/*; do chown $(awk -F/ '{print $3}' $d/homedir) -R $d; done 2>/dev/null
rm -f /usr/bin/clear-vms-home.sh
exit
}
