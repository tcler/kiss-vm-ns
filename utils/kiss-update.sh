#!/bin/bash

test $(id -u) = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

_repon=kiss-vm-ns
_confdir=/etc/$_repon

install_kiss_tools() {
	local url=https://github.com/tcler/$_repon
	local clonedir=$(mktemp -d)
	git clone $url $clonedir
	make -C $clonedir i
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
