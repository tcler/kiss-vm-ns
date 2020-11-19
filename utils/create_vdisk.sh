#!/bin/bash

create_vdisk() {
	local path=$1
	local size=$2
	local fstype=$3

	dd if=/dev/null of=$path bs=1${size//[0-9]/} seek=${size//[^0-9]/}
	local dev=$(losetup --partscan --show --find $path)
	printf "o\nn\np\n1\n\n\nw\n" | fdisk "$dev"
	partprobe "$dev"
	mkfs.$fstype $MKFS_OPT "${dev}p1"
	losetup -d $dev
}

[[ $# -lt 3 ]] && {
	cat <<-COMM
	Usage: [MKFS_OPT=xxx] $0 <image> <size> <fstype>

	Examples:
	  $0 usb.img 256M vfat
	  $0 ext4.img 4G ext4
	  MKFS_OPT="-f -i attr=2,size=512" $0 xfs.img 4G xfs
	COMM
	exit 1
}
create_vdisk "$@"
