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

get_sriov_pci_list() {
	local pat=${1:-"Virtual Function"}

        lspci -vmm |
                awk -v pattern="${pat}" '
                        BEGIN {
                                IGNORECASE=1
                                RS=""
                        }
                        $0 ~ pattern {
                                if (match($0, /Slot:.([^\n]+)\nClass:.([^\n]+)/, A)) {
                                        print ("0000:" A[1] "\t" gensub(/ /, "_", "g", A[2]))
                                }
                        }
                '
}

pci_if_list=$(get_pci_if_list)
while read slot class; do
	if ! echo "$pci_if_list" | grep $slot; then
		echo -e "${slot}\t${class}"
	fi
done < <(get_sriov_pci_list)

