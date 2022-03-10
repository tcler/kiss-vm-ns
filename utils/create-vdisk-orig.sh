#!/bin/bash
# create a virtual disk with a partion

create_vdisk() {
	local path=$1
	local size=$2
	local fstype=$3

	dd if=/dev/null of=$path bs=1${size//[0-9]/} seek=${size//[^0-9]/}
	printf "o\nn\np\n1\n\n\nw\n" | fdisk "$path"
	partprobe "$path"

	udisksctl loop-setup -f $path
	local dev=$(losetup -j $path|awk -F: '{print $1}')
	[[ -z "$dev" ]] && {
		echo "{err} 'losetup -j $path' got fail, I don't know why" >&2
		return 1
	}
	while ! ls -l ${dev}p1 2>/dev/null; do sleep 1; done
	ls -l ${dev}
	mkfs.$fstype $MKFS_OPT "${dev}p1"
	udisksctl loop-delete -b $dev
}

create_vdisk2() {
	local path=$1
	local size=$2
	local fstype=$3

	OrigUSER=$(whoami)
	[[ -n "$SUDO_USER" ]] && OrigUSER=$SUDO_USER

	sudo -u "$OrigUSER" bash <<-EOF
	dd if=/dev/null of=$path bs=1${size//[0-9]/} seek=${size//[^0-9]/}
	printf "o\nn\np\n1\n\n\nw\n" | fdisk "$path"
	partprobe "$path"
	udisksctl loop-setup -f $path
	EOF

	local dev=$(sudo -u "$OrigUSER" bash <<<"losetup -j $path" | awk -F: '{print $1}')
	[[ -z "$dev" ]] && {
		echo "{err} 'losetup -j $path' got fail, I don't know why" >&2
		return 1
	}
	ls -l ${dev}p1

	mkfs.$fstype $MKFS_OPT "${dev}p1"  #need root privileges
	sudo -u "$OrigUSER" bash <<< "udisksctl loop-delete -b $dev"
}

[[ $# -lt 3 ]] && {
	cat <<-COMM
	Usage: [MKFS_OPT=xxx] sudo $0 <image> <size> <fstype>

	Examples:
	  sudo $0 usb.img 256M vfat
	  sudo $0 ext4.img 4G ext4
	  MKFS_OPT="-f -i attr=2,size=512" sudo $0 xfs.img 4G xfs
	COMM
	exit 1
}

#create_vdisk "$@"
create_vdisk2 "$@"
