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
echo $'\n\E[0;33;44m'"{Info} showmount -e localhost"$'\E[0m'
showmount -e localhost

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

systemctl daemon-reload
systemctl start home2.automount
echo $'\n\E[0;33;44m'"{Info} getting status of systemd unit home2.mount"$'\E[0m'
systemctl status home2.mount | grep Active:

nfsmp=/mnt/nfsmp-$$
mkdir -p $nfsmp
echo $'\n\E[0;33;44m'"{Info} mount localhost:/ $nfsmp"$'\E[0m'
mount localhost:/ $nfsmp

echo $'\n\E[0;33;44m'"{Info} ls -l $nfsmp"$'\E[0m'
ls -l $nfsmp

echo $'\n\E[0;33;44m'"{Info} mount -t nfs,nfs4 | grep $nfsmp"$'\E[0m'
mount -t nfs,nfs4 | grep $nfsmp

echo $'\n\E[0;33;44m'"{Info} ls -l $nfsmp"$'\E[0m'
ls -l $nfsmp

echo $'\n\E[0;33;44m'"{Info} umount $nfsmp"$'\E[0m'
{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp
if mountpoint $nfsmp 2>/dev/null; then
	systemctl stop home2.mount
	{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp
fi

echo $'\n\E[0;33;44m'"{Info} getting status of systemd unit home2.mount again"$'\E[0m'
systemctl status home2.mount | grep Active:
if systemctl status home2.mount | grep -q mounted; then
	echo $'\n\E[0;33;44m'"{Info} stop systemd unit home2.mount"$'\E[0m'
	systemctl stop home2.mount
	echo $'\n\E[0;33;44m'"{Info} umount /home2"$'\E[0m'
	umount /home2
fi
