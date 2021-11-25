#!/bin/bash

get_pci_nic_list() {
	for ifdir in /sys/class/net/*; do
		ueventf=$ifdir/device/uevent
		if [[ -e $ueventf ]]; then
			pciAddr=$(awk -F= '/PCI_SLOT_NAME/{print $2}' $ueventf)
			echo -e "${pciAddr}\t${ifdir##*/}"
		fi
	done
}

get_sriov_pci_list() {
	lspci -vmm |
		awk '
			BEGIN {
				RS=""
			}
			/ConnectX.*Virtual Function/ {
				print "0000:" $2
			}
		'
}

pci_if_list=$(get_pci_nic_list)
for pci in $(get_sriov_pci_list); do
	if ! echo "$pci_if_list" | grep $pci; then
		echo $pci
	fi
done

