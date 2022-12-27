#!/usr/bin/env bash

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

baseurl=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio
isofname=$(curl -L -s "$baseurl" | sed -rn '/.*"(virtio-win[^"]+.iso)".*/{s//\1/;p}'|head -1)
if [[ -z "$isofname" ]]; then
	exit 2
fi
echo "$isofname"
finalurl="$baseurl/$isofname"

mkdir -p /usr/share/virtio-win
curl -L -s "$finalurl" -o /usr/share/virtio-win/$isofname
ln -sf $isofname /usr/share/virtio-win/virtio-win.iso
ls -l /usr/share/virtio-win/
