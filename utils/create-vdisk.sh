#!/bin/bash

LANG=C

create_vdiskn() {
	local path=$1
	local dsize=$2
	local fstype=$3
	local imghead=img-head-$$
	local imgtail=img-tail-$$
	local fn=${FUNCNAME[0]}

	echo -e "\n[$fn:info] creating disk and partition"
	dd if=/dev/null of=$path bs=1${dsize//[0-9]/} seek=${dsize//[^0-9]/}
	printf "o\nn\np\n1\n\n\nw\n" | fdisk "$path"
	partprobe "$path"

	read pstart psize < <( LANG=C parted -s $path unit B print | sed 's/B//g' |
		awk -v P=1 '/^Number/{start=1;next}; start {if ($1==P) {print $2, $4}}' )
	echo -e "\n[$fn:info] split disk head and partition($pstart:$psize)"
	dd if=$path of=$imghead bs=${pstart} count=1
	truncate --size=${psize} $imgtail

	echo -e "\n[$fn:info] making fs($fstype)"
	mkfs.$fstype $MKFS_OPT "$imgtail"

	echo -e "\n[$fn:info] concat image-head and partition"
	cat $imghead $imgtail >$path
	rm -vf $imghead $imgtail
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
create_vdiskn "$@"
