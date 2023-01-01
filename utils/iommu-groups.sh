#!/bin/bash

iommuGrpsRoot=/sys/kernel/iommu_groups
if [[ -z "$(ls $iommuGrpsRoot)" ]]; then
	cat <<-\EOF >&2
		{WARN} your host has not enabled iommu feature, please try follow command and reboot:
		   sudo grubby --args="intel_iommu=on iommu=pt" --update-kernel="$(/sbin/grubby --default-kernel)"
	EOF
	exit 1
fi

shopt -s nullglob
for grp in $(ls $iommuGrpsRoot | sort -V); do
	echo "IOMMU Group ${grp}:"
	for dev in $(ls $iommuGrpsRoot/$grp/devices); do
		echo "    $(lspci -nns ${dev})"
	done
done
