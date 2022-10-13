#!/bin/bash

RC=1
gitUrl=git://git.linux-nfs.org/projects/steved/nfs-utils.git

[[ -f /usr/bin/git ]] || {
	yum install -y git
}

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
