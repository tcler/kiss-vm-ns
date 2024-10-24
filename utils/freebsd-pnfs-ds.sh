#!/bin/sh

grep -q =FreeBSD /etc/os-release || { echo "{WARN} this script is only for FreeBSD OS"; exit 1; }

topdir="/pnfs-ds-storage"
mkdir -p -m 700 $topdir
(cd $topdir; jot -w ds 20 0 | xargs mkdir -p -m 700)

cat <<EOF >/etc/exports
$topdir -maproot=root -sec=sys
V4: $topdir -sec=sys
EOF

#enable nfs server
egrep -i ^nfs_server_enable=.?YES /etc/rc.conf ||
cat <<EOF >>/etc/rc.conf
rpcbind_enable="YES"
nfs_server_enable="YES"
nfsv4_server_enable="YES"
nfsuserd_enable="YES"
mountd_enable="YES"
nfs_server_flags="-u -t -n 32"
mountd_flags="-S"
nfsuserd_flags="-manage-gids"
EOF
service nfsd start
service mountd restart
service nfsuserd start

#enable nfs client
egrep -i ^nfs_client_enable=.?YES /etc/rc.conf ||
echo 'nfs_client_enable="YES"' >>/etc/rc.conf
service nfsclient start

#enable nfs locking
egrep -i ^rpc_lockd_enable=.?YES /etc/rc.conf ||
echo 'rpc_lockd_enable="YES"' >>/etc/rc.conf
service lockd start

#enable nfs stat
egrep -i ^rpc_statd_enable=.?YES /etc/rc.conf ||
echo 'rpc_statd_enable="YES"' >>/etc/rc.conf
service statd start

