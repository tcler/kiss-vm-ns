#!/bin/bash
#let user do udisksctl loop-setup/loop-delete without password
#
LANG=C
shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

#__main__
switchroot "$@"

#change policy org.freedesktop.UDisks2.policy or org.freedesktop.udisks2.policy on debian
#see also: https://lists.debian.org/debian-devel/2017/01/msg00081.html
sed -ri -e '/(filesystem-mount"|loop-setup|loop-delete)/,/<\/action>/{s/auth_admin[_a-z]*\>/yes/}' \
	/usr/share/polkit-1/actions/org.freedesktop.??isks2.policy
