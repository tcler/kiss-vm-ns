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

nouring=$1

# clone xfstests in background
command -v git || _deps=git; command -v tmux || _deps+=" tmux"
[[ -n "$_deps" ]] && yum install -y $_deps
tgzUrl=https://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git/snapshot/xfstests-dev-master.tar.gz
backupUrl=https://github.com/kdave/xfstests/archive/refs/heads/master.tar.gz
downloadSession=download-xfstests-$$
tmux new -s $downloadSession -d "{ curl -LO $tgzUrl && tar axf ${tgzUrl##*/} || curl -LO $backupUrl && tar axf ${backupUrl##*/}; }"

#Prepare: install deps
yum clean packages
yum install -y --nogpgcheck acl attr automake bc dbench dump e2fsprogs fio gawk gcc \
	gdbm-devel git indent kernel-devel libacl-devel \
	libcap-devel libtool libuuid-devel lvm2 make psmisc \
	python3 quota sed sqlite udftools xfsprogs xfsprogs-devel
grep -q CONFIG_AIO=y /boot/config-$(uname -r) && yum install -y libaio-devel
#https://unix.stackexchange.com/questions/596276/how-to-tell-if-a-linux-machine-supports-io-uring
[[ -z "$nouring" ]] && grep -q io_uring_setup /proc/kallsyms && {
	test -f /proc/sys/kernel/io_uring_disabled && sysctl kernel.io_uring_disabled=0
	yum install -y liburing-devel
}

# wait clone finish
while tmux ls | grep $downloadSession; do sleep 8; done

#Install form src
dir=xfstests-dev-master; test -d $dir || dir=xfstests-master
cd $dir && make && make install

# Check install result
ls -lF /var/lib/xfstests/
