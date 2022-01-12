#!/bin/bash

iommuGrpsRoot=/sys/kernel/iommu_groups

shopt -s nullglob
for grp in $(ls $iommuGrpsRoot | sort -V); do
	echo "IOMMU Group ${grp}:"
	for dev in $(ls $iommuGrpsRoot/$grp/devices); do
		echo "    $(lspci -nns ${dev})"
	done
done
