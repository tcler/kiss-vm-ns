#!/bin/bash

Usage() { echo -e "Usage: ${0} <src.rpm> [p|b]"; }
[[ $# = 0 ]] && { Usage >&2; exit 1; }

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
	target=.
	[[ "$EUID" = 0 ]] && target=/usr/src
	mv -f ~/rpmbuild/BUILD/* $target/
elif [[ "$buildtype" = b ]]; then
	mv -f ~/rpmbuild/RPMS/$(uname -m)/* ./.
fi
