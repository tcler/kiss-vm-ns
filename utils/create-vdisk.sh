#!/bin/bash
#
#for creating disk image with partition and filesystem as non-root user
#
#update 2022-03-11: just found out that 'virt-make-fs' has already implemented
#same function. please use 'virt-make-fs' instead for most cases:
#$ virt-make-fs -s $size -t $fstype $dir_or_tar $image --partition
#
#still keep this script as a souvenir

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

create_vdiskm() {
	local path=$1
	local dsize=$2
	local fstype=$3
	local fsroot=$4 _fsroot=
	local fn=${FUNCNAME[0]}

	[[ -z "$fsroot" ]] && _fsroot=$(mktemp -d) || _fsroot=$fsroot
	virt-make-fs -v --partition --label=label \
		-s "$dsize" -t "$fstype" "$_fsroot" "$path"
	[[ -z "$fsroot" ]] && rmdir "$_fsroot"
}

[[ $# -lt 3 ]] && {
	cat <<-COMM
	Usage: [MKFS_OPT=xxx] $0 <image> <size> <fstype> [fsroot]

	Examples:
	  $0 usb.img 256M vfat
	  $0 ext4.img 4G ext4
	  MKFS_OPT="-f -i attr=2,size=512" $0 xfs.img 4G xfs
	COMM
	exit 1
}
create_vdiskn "$@"
