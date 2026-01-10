#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#for: install xfstests from source code

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

for arg; do [[ "$arg" = *=* ]] && eval "$arg"; done

(mkdir -p /usr/src; cd /usr/src
# download xfstests in background
command -v git || _deps=git; command -v tmux || _deps+=" tmux"
[[ -n "$_deps" ]] && yum install -y $_deps
tgzUrl=https://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git/snapshot/xfstests-dev-master.tar.gz
backupUrl=https://github.com/kdave/xfstests/archive/refs/heads/master.tar.gz
downloadSession=download-xfstests-$$
tmux new -s $downloadSession -d "{ curl -LO $tgzUrl && tar axf ${tgzUrl##*/} || curl -LO $backupUrl && tar axf ${backupUrl##*/}; }"

#Prepare: install deps
yum clean packages
yum remove libperf-devel -y 2>/dev/null
yum install -y --setopt=strict=0 --nogpgcheck acl attr automake \
	bc dbench dump e2fsprogs fio gawk gcc gdbm-devel git indent \
	kernel-devel libacl-devel libcap-devel libtool libuuid-devel lvm2 \
	make psmisc python3 quota sed sqlite udftools xfsprogs xfsprogs-devel ndctl
grep -q CONFIG_AIO=y /boot/config-$(uname -r) && yum install -y libaio-devel
#https://unix.stackexchange.com/questions/596276/how-to-tell-if-a-linux-machine-supports-io-uring
[[ -z "$nouring" ]] && grep -q io_uring_setup /proc/kallsyms && {
	test -f /proc/sys/kernel/io_uring_disabled && sysctl kernel.io_uring_disabled=0
	yum install -y liburing-devel
}

# wait download finish
while tmux ls | grep $downloadSession; do sleep 8; done

#Install form src
dir=xfstests-dev-master; test -d $dir || dir=xfstests-master
cd $dir && make && make install
)

# Check install result
ls -lF /var/lib/xfstests/
