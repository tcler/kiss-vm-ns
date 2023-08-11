#!/bin/bash
# author: Jianhong Yin <yin-jianhong@163.com>
# configure nfs service and start

export LANG=C

## global var
PREFIX=/nfsshare


## argparse
P=${0##*/}
Usage() {
	cat <<EOF
Usage:
  sudo $P [options]

Options:
  -h, -help              ; show this help
  -prefix <path>         ; root directory of nfs share(default: /nfsshare/)
  -t                     ; run extra tests after nfs start
EOF
}
test `id -u` = 0 || { echo "{Warn} This command has to be run under the root user"|grep --color=always . >&2; Usage >&2; exit 1; }

srun() {
	local cmdline=$1 expect_ret=${2:-0} comment=${3}
	local ret=0
	_lcontains() { [[ "${1//,/ }" =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1; }
	echo $'\E[0;33;44m'"[$(date +%T) $USER@ ${PWD%%*/}]> $cmdline"$'\E[0m'
	eval $cmdline
	ret=$?
	[[ $expect_ret != - ]] && ! _lcontains ${expect_ret} $ret && {
		echo $'\E[41m'"${comment:-{error} expected $expect_ret, but get $ret}"$'\E[0m' >&2
		let retcode++
	}
	return $ret
}


_at=$(getopt -a -o ht \
	--long help \
	--long test \
	--long prefix: \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)    Usage; shift 1; exit 0;;
	-t|--test)    eTEST=yes; shift 1;;
	--prefix)     PREFIX=$2; shift 2;;
	--) shift; break;;
	esac
done


## install related packages
rpm -q nfs-utils || yum install -y nfs-utils &>/dev/null
#yum install -y krb5-workstation &>/dev/null


## create nfs export directorys
mkdir -p $PREFIX/{ro,rw,async,labelled-nfs,qe,devel}
chgrp nobody -R $PREFIX
chmod g+ws -R $PREFIX
touch $PREFIX/{ro,rw,async,labelled-nfs,qe,devel}/testfile
semanage fcontext -a -t nfs_t "$PREFIX(/.*)?"
restorecon -Rv $PREFIX
chmod 775 -R $PREFIX/{rw,async,labelled-nfs,qe,devel}


## generate exports config file
defaultOpts=${defaultOpts:-insecure}
cat <<EOF >/etc/exports
$PREFIX/ro *(${defaultOpts},ro)
$PREFIX/rw *(${defaultOpts},rw,root_squash,sec=sys:krb5:krb5i:krb5p)
$PREFIX/async *(${defaultOpts},rw,root_squash,async,sec=sys:krb5:krb5i:krb5p)
$PREFIX/labelled-nfs *(${defaultOpts},rw,root_squash,security_label,sec=sys:krb5:krb5i:krb5p)
$PREFIX/qe *(${defaultOpts},rw,root_squash,sec=sys:krb5:krb5i:krb5p)
$PREFIX/devel *(${defaultOpts},rw,root_squash,sec=sys:krb5:krb5i:krb5p)
EOF
srun "cat /etc/exports"

## start nfs-server service
systemctl enable nfs-server
srun "systemctl restart nfs-server"

## test/verify
srun "showmount -e localhost"

[[ "$eTEST" != yes ]] && exit

## one more test about nfsv4 pseudo-filesystem
cat <<EOF >/etc/systemd/system/home2.automount
[Unit]
Description=EFI System Partition Automount
Documentation=TBD
[Automount]
Where=/home2
TimeoutIdleSec=120
EOF

cat <<EOF >/etc/systemd/system/home2.mount
[Unit]
Description=EFI System Partition Automount
Documentation=TBD
[Mount]
What=/home
Where=/home2
Type=$(stat -f -c %T /home)
Options=ro,bind
EOF

srun "systemctl daemon-reload"
srun "systemctl start home2.automount"
srun "systemctl status home2.mount | grep Active:" -

nfsmp=/mnt/nfsmp-$$
srun "mkdir -p $nfsmp"
srun "mount localhost:/ $nfsmp"

srun "touch $nfsmp/nfsshare/rw/file"
srun "ls -l $nfsmp $nfsmp/nfsshare/rw"
srun "mount -t nfs,nfs4 | grep $nfsmp"
srun "ls -l $nfsmp"

srun "{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp"

srun "systemctl status home2.mount | grep Active:"
srun "systemctl status home2.mount | grep mounted"
srun "systemctl stop home2.automount"
srun "mountpoint /home2" 32,1
