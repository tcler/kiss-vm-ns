#!/bin/bash

winiso=$1
[[ -z "$winiso" ]] && { echo "Usage: $0 <windows-iso>" >&2; exit 1; }

command -v wiminfo >/dev/null || {
	echo "command 'wiminfo' not found, please install wimlib first by using: (sudo `command -v wimlib-install.sh`)" >&2;
	exit 1;
}

#read dev < <(virt-filesystems -a $winiso)
tmpmp=$(mktemp -d)
guestmount -a $winiso --ro -m ${dev:-/dev/sda} $tmpmp
wiminfo $tmpmp/sources/install.wim
guestunmount $tmpmp && rmdir $tmpmp
