#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#for: install nfstest from source code

_url='http://git.linux-nfs.org/?p=mora/nfstest.git;a=snapshot;h=HEAD;sf=tgz'
_tarf=nfstest.tgz
_xdir=nfstest
targetdir=/usr/src; [[ $(id -u) != 0 ]] && { targetdir=${HOME}/src; }
mkdir -p ${targetdir}/$_xdir

#install and extract
echo "{info} install-nfstest from '$_url'"
curl -k -Ls "$_url" -o ${targetdir}/$_tarf
pushd $targetdir &>/dev/null
	echo "{info} extract $_tarf to $targetdir/$_xdir  "
	tar -C $_xdir -zxf $_tarf --strip-components=1
popd &>/dev/null

#export env
_envf=/tmp/nfstest.env
cat <<-EOF >$_envf
export PYTHONPATH=$targetdir/$_xdir
export PATH=$targetdir/$_xdir/test:$PATH
EOF
echo "{info} please source '$_envf', and run your tests"
