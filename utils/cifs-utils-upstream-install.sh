#!/bin/bash

RC=1
gitUrl=git://git.samba.org/cifs-utils.git
pkgs='git make autoconf automake'
deppkgs='libtalloc-devel libcap-devel keyutils-libs-devel libwbclient-devel krb5-devel pam-devel'

if command -v dnf &>/dev/null; then
	dnf install -y $pkgs $deppkgs
elif command -v apt &>/dev/null; then
	apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y $pkgs
elif command -v zypper &>/dev/null; then
	zypper in --no-recommends -y $pkgs
elif command -v pacman &>/dev/null; then
	pacman -Sy --noconfirm $pkgs
fi

rm -rf cifs-utils
if git clone $gitUrl; then
	pushd cifs-utils
		autoreconf -i
		if ./configure && make && make install; then
			mount.cifs -V
			RC=0
		fi
	popd
fi

exit $RC
