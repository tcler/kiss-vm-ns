#!/bin/bash

LANG=C
PROG=${0##*/}

mount_vdisk2() {
	local path=$1
	local partN=${2:-1}
	local dev= mntdev= mntopt= mntinfo=

	read dev _ < <(losetup -j $path|awk -F'[: ]+' '{print $1, $2}')
	if [[ -z "$dev" ]]; then
		udisksctl loop-setup -f $path >&2
		read dev _ < <(losetup -j $path|awk -F'[: ]+' '{print $1, $2}')
	fi
	[[ -z "$dev" ]] && {
		echo "{err} 'losetup -j $path' got fail, I don't know why" >&2
		return 1
	}

	mntdev=${dev}p${partN}
	{ ls -l ${mntdev}; } >&2

	mntinfo=$(mount | awk -v d=$mntdev '$1 == d')
	loinfo=$(losetup -j $path)
	if [[ -z "$mntinfo" ]]; then
		mntopt=$([[ -n "$MNT_OPT" ]] && echo --options=$MNT_OPT)
		udisksctl mount -b $mntdev $mntopt >&2
	else
		echo -e "{warn} '$path' has been already mounted:\n  $mntinfo" >&2
	fi

	echo -e "  $loinfo" >&2
	mount | awk -v d=$mntdev '$1 == d {print $3}'
}

[[ $# -lt 1 ]] && {
	cat <<-COMM
	Usage: [MNT_OPT=xxx] $0 <image> [partition Number]

	Examples:
	  $0 usb.img
	  $0 ext4.img 1
	  MNT_OPT="-oro" $0 xfs.img 2
	COMM
	exit 1
}

mount_vdisk2 "$@"
