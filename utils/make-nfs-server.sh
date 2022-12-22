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
EOF
}
test `id -u` = 0 || { echo "{Warn} This command has to be run under the root user"|grep --color=always . >&2; Usage >&2; exit 1; }

_at=$(getopt -a -o h \
	--long help \
	--long prefix: \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)    Usage; shift 1; exit 0;;
	--prefix)     PREFIX=$2; shift 2;;
	--) shift; break;;
	esac
done


## install related packages
yum install -y nfs-utils &>/dev/null
#yum install -y krb5-workstation &>/dev/null


## create nfs export directorys
mkdir -p $PREFIX/{ro,rw,async,labelled-nfs,krb5-nfs1,krb5-nfs2}
touch $PREFIX/{ro,rw,async,labelled-nfs,krb5-nfs1,krb5-nfs2}/testfile
chmod -R 777 $PREFIX


## generate exports config file
defaultOpts=${defaultOpts:-insecure}
cat <<EOF >/etc/exports
$PREFIX/ro *(${defaultOpts},ro)
$PREFIX/rw *(${defaultOpts},rw,no_root_squash)
$PREFIX/async *(${defaultOpts},rw,no_root_squash,async)
$PREFIX/labelled-nfs *(${defaultOpts},rw,no_root_squash,security_label)
$PREFIX/krb5-nfs1 *(${defaultOpts},rw,no_root_squash,sec=sys:krb5:krb5i:krb5p)
$PREFIX/krb5-nfs2 *(${defaultOpts},rw,no_root_squash,sec=sys:krb5:krb5i:krb5p)
EOF


## start nfs-server service
systemctl enable nfs-server
systemctl restart nfs-server

## test/verify
showmount -e localhost

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

systemctl start home2.automount

nfsmp=/mnt/nfsmp-$$
mkdir -p $nfsmp
mount localhost:/ $nfsmp
mount -t nfs,nfs4 | grep $nfsmp
ls -l $nfsmp
{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp
mountpoint $nfsmp && {
	systemctl stop home2.mount
	{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp
}
