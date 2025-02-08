#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#for: install xfsprogs upstream from source code

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

for arg; do [[ "$arg" = *=* ]] && eval "$arg"; done

# download xfsprogs
# stabes: https://mirrors.edge.kernel.org/pub/linux/utils/fs/xfs/xfsprogs/
command -v tmux || _deps+=" tmux"
[[ -n "$_deps" ]] && yum install -y $_deps
tgzUrl=https://git.kernel.org/pub/scm/fs/xfs/xfsprogs-dev.git/snapshot/xfsprogs-dev-master.tar.gz
downloadSession=download-xfsprogs-$$
tmux new -s $downloadSession -d "{ curl -LO $tgzUrl && tar axf ${tgzUrl##*/}; }"

#Prepare: install deps
yum clean packages
yum install --nogpgcheck -y inih-devel userspace-rcu-devel \
	libtool libuuid-devel libblkid-devel 

# wait download finish
while tmux ls | grep $downloadSession; do sleep 8; done

#Install form src
dir=xfsprogs-dev-master
cd $dir && make && make install
