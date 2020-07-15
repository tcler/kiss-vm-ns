#!/bin/bash

sharedir=~/sharedir
vmname=vm-virtiofs-submount

mkdir -p $sharedir/{ext4,xfs,xfs2,testdir}
dd if=/dev/zero of=~/ext4.img bs=1M count=512
dd if=/dev/zero of=~/xfs.img bs=1M count=512
dd if=/dev/zero of=~/xfs2.img bs=1M count=512
mkfs.ext4 ~/ext4.img
mkfs.xfs ~/xfs.img
mkfs.xfs ~/xfs2.img
sudo mount -t ext4 ~/ext4.img $sharedir/ext4
sudo mount -t xfs ~/xfs.img $sharedir/xfs
sudo mount -t xfs ~/xfs2.img $sharedir/xfs2

vm rhel-8.3% -n $vmname  --sharedir  $sharedir:hostshare -f

vm exec $vmname -- mount -t virtiofs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs2
sudo touch $sharedir/xfs/{1..16} $sharedir/xfs2/{1..16} $sharedir/testdir/{1..16}
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs2 | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/testdir | sort -n | head
[jianhong@localhost ~]$ cat virtiofs-submount.sh

sharedir=~/sharedir
mkdir -p $sharedir/{ext4,xfs,xfs2,testdir}
dd if=/dev/zero of=~/ext4.img bs=1M count=512
dd if=/dev/zero of=~/xfs.img bs=1M count=512
dd if=/dev/zero of=~/xfs2.img bs=1M count=512
mkfs.ext4 ~/ext4.img
mkfs.xfs ~/xfs.img
mkfs.xfs ~/xfs2.img
sudo mount -t ext4 ~/ext4.img $sharedir/ext4
sudo mount -t xfs ~/xfs.img $sharedir/xfs
sudo mount -t xfs ~/xfs2.img $sharedir/xfs2

vm rhel-8.3% -n $vmname  --sharedir  $sharedir:hostshare -f

vm exec $vmname -- mount -t virtiofs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs2
sudo touch $sharedir/xfs/{1..16} $sharedir/xfs2/{1..16} $sharedir/testdir/{1..16}
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs2 | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/testdir | sort -n | head

