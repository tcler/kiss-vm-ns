#!/bin/bash

iommuGrpsRoot=/sys/kernel/iommu_groups
if [[ -z "$(ls $iommuGrpsRoot)" ]]; then
	if grep -q AuthenticAMD /proc/cpuinfo; then
		kernelopts="amd_iommu=on"
	elif grep -q GenuineIntel /proc/cpuinfo; then
		kernelopts="intel_iommu=on iommu=pt"
	fi

	if [[ -n "$kernelopts" ]]; then
		cat <<-EOF >&2
			{WARN} your host has not enabled iommu feature, please try follow command and reboot:
			   sudo grubby --args="$kernelopts" --update-kernel=DEFAULT
			   #or
			   sudo sed -i '/'"$kernelopts"'/!{/GRUB_CMDLINE_LINUX/s/"$/'" $kernelopts"'"/}' /etc/default/grub
			   sudo grub2-mkconfig | sudo tee /boot/grub2/grub.cfg /boot/efi/EFI/fedora/grub.cfg
		EOF
	else
		echo "{WARN} your host has not enabled iommu feature."
	fi
	exit 1
fi

shopt -s nullglob
for grp in $(ls $iommuGrpsRoot | sort -V); do
	echo "IOMMU Group ${grp}:"
	for dev in $(ls $iommuGrpsRoot/$grp/devices); do
		echo "    $(lspci -nns ${dev})"
	done
done
