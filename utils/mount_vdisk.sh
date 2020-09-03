#!/bin/bash

mount_vdisk() {
	local path=$1
	local mp=$2
	local partN=${3:-1}
	local offset=$(fdisk -l -o Start "$path" |
		awk -v N=$partN '
			/^Units:/ { unit=$(NF-1); offset=0; }
			/^Start/ {
				for(i=0;i<N;i++)
					if(getline == 0) { $0=""; break; }
				offset=$1*unit;
			}
			END { print offset; }'
	)
	echo "offset: $offset"

	[[ -d "$mp" ]] || {
		echo "{warn} mount_vdisk: dir '$mp' not exist"
		return 1
	}

	if [[ "$offset" -ne 0 || "$partN" -eq 1 ]]; then
		mount $MNT_OPT -oloop,offset=$offset $path $mp
	else
		echo "{warn} mount_vdisk: there's not part($partN) on disk $path"
		return 1
	fi
}

[[ $# -lt 2 ]] && {
	cat <<-COMM
	Usage: [MNT_OPT=xxx] $0 <image> <mountpoint> [partition Number]

	Examples:
	  $0 usb.img /mnt/usb
	  $0 ext4.img /mnt/ext4
	  MNT_OPT="-oro" $0 xfs.img /mnt/xfstest 2
	COMM
	exit 1
}
mount_vdisk "$@"
