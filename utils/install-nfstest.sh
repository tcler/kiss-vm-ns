#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#for: install nfstest from source code

#install python3 for rhel/centos/fedora
command -v python3 || {
	OSVER=$(rpm -E %rhel)
	if [[ $OSVER != %rhel && $OSVER -lt 9 ]]; then
		case $OSVER in
		8) sudo yum install -y python39;;
		7) sudo yum install -y python36;;
		6) sudo yum install -y python34;;
		*) echo "[WARN] does not support rhel-5 and before.";;
		esac
	else
		sudo yum install -y python3
	fi
}

_url='http://git.linux-nfs.org/?p=mora/nfstest.git;a=snapshot;h=HEAD;sf=tgz'
_tarf=nfstest.tgz
_xdir=nfstest
targetdir=/usr/src; test -f /run/ostree-booted && targetdir=/var/src
[[ $(id -u) != 0 ]] && { targetdir=${HOME}/src; }
mkdir -p ${targetdir}/$_xdir

#install and extract
echo "{info} install-nfstest from '$_url'"
while ! test -f $targetdir/$_tarf; do
	while ! curl -fkLs "$_url" -o ${targetdir}/$_tarf; do sleep 5; done
done
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
cat $_envf >>~/.bashrc
