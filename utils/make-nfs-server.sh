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
cat <<EOF >/etc/exports
$PREFIX/ro *(ro)
$PREFIX/rw *(rw,no_root_squash)
$PREFIX/async *(rw,no_root_squash,async)
$PREFIX/labelled-nfs *(rw,no_root_squash,security_label)
$PREFIX/krb5-nfs1 *(rw,no_root_squash,sec=sys:krb5:krb5i:krb5p)
$PREFIX/krb5-nfs2 *(rw,no_root_squash,sec=sys:krb5:krb5i:krb5p)
EOF


## start nfs-server service
systemctl restart nfs-server

## test/verify
showmount -e localhost
