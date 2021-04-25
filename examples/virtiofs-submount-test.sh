#!/bin/bash

sharedir=~/sharedir
vmname=vm-virtiofs-submount
distro=${1:-rhel-8.3%}
user=$LOGNAME

which vm &>/dev/null || {
	echo -e "[WARN] you have not installed kiss-vm, please install kiss-vm first by run:"
	echo -e " git clone https://github.com/tcler/kiss-vm-ns"
	echo -e " sudo make -C kiss-vm-ns"
	echo -e " vm prepare"
	exit 1
}

mkdir -p $sharedir/{ext4,xfs,xfs2,testdir}
dd if=/dev/zero of=~/ext4.img bs=1M count=512 status=noxfer
dd if=/dev/zero of=~/xfs.img bs=1M count=512 status=noxfer
dd if=/dev/zero of=~/xfs2.img bs=1M count=512 status=noxfer
mkfs.ext4 ~/ext4.img
mkfs.xfs ~/xfs.img
mkfs.xfs ~/xfs2.img
sudo mount -t ext4 ~/ext4.img $sharedir/ext4
sudo mount -t xfs ~/xfs.img $sharedir/xfs
sudo mount -t xfs ~/xfs2.img $sharedir/xfs2
sudo chown -R $user $sharedir/{ext4,xfs,xfs2}

vm $distro -n $vmname  --sharedir  $sharedir:hostshare -f

vm exec $vmname -- mount -t virtiofs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs
vm exec $vmname -- mountpoint /virtiofs/hostshare/xfs2
touch $sharedir/xfs/{1..16} $sharedir/xfs2/{1..16} $sharedir/testdir/{1..16}
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/xfs2 | sort -n | head
vm exec -v $vmname -- ls -li /virtiofs/hostshare/testdir | sort -n | head

