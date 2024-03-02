#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#for: install xfstests from source code

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

#Prepare: install deps
yum install -y acl attr automake bc dbench dump e2fsprogs fio gawk gcc \
	gdbm-devel git indent kernel-devel libacl-devel libaio-devel \
	libcap-devel libtool liburing-devel libuuid-devel lvm2 make psmisc \
	python3 quota sed sqlite udftools xfsprogs xfsprogs-devel

# clone
pkg=xfstests
gitUrl=git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git
backupUrl=https://github.com/kdave/xfstests
git clone $gitUrl $pkg || git clone $backupUrl $pkg

#Install form src
cd $pkg && make && make install

# Check install result
ls -lF /var/lib/xfstests/
