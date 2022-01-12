#!/bin/bash

shopt -s nullglob
for grp in /sys/kernel/iommu_groups/*; do
	echo "IOMMU Group ${grp##*/}:"
	for dev in $grp/devices/*; do
		echo "    $(lspci -nns ${dev##*/})"
	done
done
