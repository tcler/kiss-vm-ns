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

# clone xfstests in background
command -v git || _deps=git; command -v tmux || _deps+=" tmux"
[[ -n "$_deps" ]] && yum install -y $_deps
pkg=xfstests
gitUrl=git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git
backupUrl=https://github.com/kdave/xfstests
cloneSession=clone-xfstests-$$
tmux new -s $cloneSession -d "git clone $gitUrl $pkg || git clone $backupUrl $pkg"

#Prepare: install deps
yum install -y acl attr automake bc dbench dump e2fsprogs fio gawk gcc \
	gdbm-devel git indent kernel-devel libacl-devel \
	libcap-devel libtool libuuid-devel lvm2 make psmisc \
	python3 quota sed sqlite udftools xfsprogs xfsprogs-devel
grep -q CONFIG_AIO=y /boot/config-$(uname -r) && yum install -y libaio-devel
#https://unix.stackexchange.com/questions/596276/how-to-tell-if-a-linux-machine-supports-io-uring
grep -q io_uring_setup /proc/kallsyms && {
	sysctl kernel.io_uring_disabled=0
	yum install -y liburing-devel
}

# wait clone finish
while tmux ls | grep $cloneSession; do sleep 8; done

#Install form src
cd $pkg && make && make install

# Check install result
ls -lF /var/lib/xfstests/
