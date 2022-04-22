#!/bin/bash

isof=$1
mp=$2
[[ -z "$isof" || -z "$mp" ]] && { echo "Usage: $0 <iso-file> <mount-point>" >&2; exit 1; }

command -v guestmount >/dev/null || {
	echo "command 'guestmount' is required, please install package libguestfs first." >&2;
	exit 1;
}

#read dev < <(virt-filesystems -a $isof)
guestmount -a $isof --ro -m ${dev:-/dev/sda} $mp
