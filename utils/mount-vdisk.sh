#!/bin/bash

LANG=C
PROG=${0##*/}

mount_vdisk2() {
	local fn=${FUNCNAME[0]}
	local CNT=$(sed -rn -e '/(filesystem-mount"|loop-setup)/,/<\/action>/{/<allow_any>yes/p}' \
		/usr/share/polkit-1/actions/org.freedesktop.UDisks2.policy | wc -l)
	if [[ "$CNT" -lt 2 && $(id -u) -ne 0 ]]; then
		echo "{$fn:err} udisks2 policy does not support non-root user loop-setup,mount yet" >&2
		[[ -z "$DISPLAY" ]] && return 1
	fi

	local path=$1
	local partN=${2:-1}
	local dev= mntdev= mntopt= mntinfo=

	read dev _ < <(losetup -j $path|awk -F'[: ]+' '{print $1, $2}')
	if [[ -z "$dev" ]]; then
		udisksctl loop-setup -f $path >&2
		read dev _ < <(losetup -j $path|awk -F'[: ]+' '{print $1, $2}')
	fi
	[[ -z "$dev" ]] && {
		echo "{$fn:err} 'losetup -j $path' got fail, I don't know why" >&2
		return 1
	}

	mntdev=${dev}p${partN}
	ls ${dev}p* &>/dev/null || mntdev=$dev
	{ ls -l ${mntdev}; } >&2

	mntinfo=$(mount | awk -v d=$mntdev '$1 == d')
	loinfo=$(losetup -j $path)
	if [[ -z "$mntinfo" ]]; then
		mntopt=$([[ -n "$MNT_OPT" ]] && echo --options=$MNT_OPT)
		udisksctl mount -b $mntdev $mntopt >&2
	else
		echo -e "{$fn:warn} '$path' has been already mounted:\n  $mntinfo" >&2
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
