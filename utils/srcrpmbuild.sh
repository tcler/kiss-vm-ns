#!/bin/bash

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

Usage() { echo -e "Usage: sudo ${0} <src.rpm> [p|b]"; }
[[ $# = 0 ]] && { Usage >&2; exit 1; }

switchroot "$@"
which rpmbuild &>/dev/null || yum install -y /usr/bin/rpmbuild

pkg=$1
buildtype=${2:-p}

[[ "$buildtype" = b ]] && {
	which gcc &>/dev/null || yum install -y gcc
}

mkdir -p ~/rpmbuild
rm -rf ~/rpmbuild/*
rpm -ivh $pkg
std=$(rpmbuild -b${buildtype} ~/rpmbuild/SPECS/*.spec 2>&1)
if grep ^error: <<<"$std"; then
	sudo yum install -y $(echo "$std"| awk '/is needed by/{print $1}')
	rpmbuild -b${buildtype} ~/rpmbuild/SPECS/*.spec
else
	echo "$std"
fi

if [[ "$buildtype" = p ]]; then
	srcdir=/usr/src
	if [[ $pkg = kernel-[0-9].*.src.rpm ]]; then
		read kdir _ <<<$(ls -d ~/rpmbuild/BUILD/*/linux-[0-9]*)
		mv -f -T $kdir ${srcdir}/${kdir##*/}
	else
		mv -f ~/rpmbuild/BUILD/* ${srcdir}/
	fi
elif [[ "$buildtype" = b ]]; then
	mv -f ~/rpmbuild/RPMS/$(uname -m)/* ./.
fi
