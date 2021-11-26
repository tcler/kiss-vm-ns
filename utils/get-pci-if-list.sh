#!/bin/bash

get_pci_if_list() {
	for ifdir in /sys/class/net/*; do
		ueventf=$ifdir/device/uevent
		if [[ -e $ueventf ]]; then
			pciAddr=$(awk -F= '/PCI_SLOT_NAME/{print $2}' $ueventf)
			echo -e "${pciAddr}\t${ifdir##*/}"
		fi
	done
}

get_pci_if_list | sed -e 's/^/pci_/' -e 's/[:.]/_/g'
