#!/bin/bash

VMSHOME=~/VMs
for vmdir in $VMSHOME/*/*; do
	vmname=${vmdir##*/}
	if ! virsh desc $vmname &>/dev/null; then
		rm -rf $vmdir
	elif ! virsh dumpxml --domain $vmname|grep -q $vmdir; then
		rm -rf $vmdir
	fi
done
rmdir $VMSHOME/* 2>/dev/null
