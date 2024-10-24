#!/bin/sh

grep -q =FreeBSD /etc/os-release || { echo "{WARN} this script is only for FreeBSD OS"; exit 1; }

#enable nfs client
egrep -i ^nfs_client_enable=.?YES /etc/rc.conf ||
echo 'nfs_client_enable="YES"' >>/etc/rc.conf
service nfsclient start

#enable nfscbd
egrep -i ^nfscbd_enable=.?YES /etc/rc.conf ||
echo 'nfscbd_enable="YES"' >>/etc/rc.conf
service nfscbd start
