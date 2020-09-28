#!/bin/bash

qcow2img=$1

freenbd() {
	for x in /sys/class/block/nbd*; do
		S=$(< $x/size)
		[[ "$S" == "0" ]] && {
			echo -n /dev/${x##*/}
			break
		}
	done
}

# nbd module
modprobe nbd max_part=64

dev=$(freenbd)
qemu-nbd --connect=$dev $qcow2img &&
	echo $dev

[[ "$DEBUG" = yes ]] && {
	fdisk -l $dev
	qemu-nbd --disconnect $dev
}
