#!/bin/bash

RC=1
gitUrl=git://git.linux-nfs.org/projects/steved/nfs-utils.git

if ! { command -v git && command -v make; }; then
	if command -v dnf &>/dev/null; then
		dnf install -y git make
	elif command -v apt &>/dev/null; then
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y git make
	elif command -v zypper &>/dev/null; then
		zypper in --no-recommends -y git make
	elif command -v pacman &>/dev/null; then
		pacman -Sy --noconfirm git make
	fi
fi

if git clone $gitUrl; then
	pushd nfs-utils
		bash install-dep
		if ./autogen.sh && ./configure && make && make install; then
			mount.nfs -V
			RC=0
		fi
	popd
fi

exit $RC
