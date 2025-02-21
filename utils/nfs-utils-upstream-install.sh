#!/bin/bash

RC=1
gitUrl=git://git.linux-nfs.org/projects/steved/nfs-utils.git
pkgs='git make'

if command -v dnf &>/dev/null; then
	dnf install -y $pkgs
elif command -v apt &>/dev/null; then
	apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y $pkgs
elif command -v zypper &>/dev/null; then
	zypper in --no-recommends -y $pkgs
elif command -v pacman &>/dev/null; then
	pacman -Sy --noconfirm $pkgs
fi

rm -rf nfs-utils
if git clone $gitUrl; then
	pushd nfs-utils
		bash install-dep
		#now (2025-02-21) the install-dep is not cover all dependency that required by configure
		#here is a workaround on fedora/rhel os
		dnf install -y libmount-devel libnl3-devel readline-devel libxml2-devel
		if ./autogen.sh && ./configure && make && make install; then
			mount.nfs -V
			RC=0
		fi
	popd
fi

exit $RC
