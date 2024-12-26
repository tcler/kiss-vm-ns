#!/bin/bash
#let user do udisksctl loop-setup/loop-delete without password
#
LANG=C
switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

#__main__
switchroot "$@"

#change policy org.freedesktop.UDisks2.policy or org.freedesktop.udisks2.policy on debian
#see also: https://lists.debian.org/debian-devel/2017/01/msg00081.html
sed -ri -e '/(filesystem-mount"|loop-setup|loop-delete)/,/<\/action>/{s/auth_admin[_a-z]*\>/yes/}' \
	/usr/share/polkit-1/actions/org.freedesktop.??isks2.policy
