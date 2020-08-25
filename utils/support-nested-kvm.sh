#!/bin/bash

support_nested_kvm() {
	local kmodule=$(lsmod|awk '$1 == "kvm" {print $NF}')
	local rc=0

	if [[ $(< /sys/module/$kmodule/parameters/nested) != [Yy1] ]]; then
		rc=1
	fi
	test "$debug" = yes && cat /sys/module/$kmodule/parameters/nested
	return $rc
}

support_nested_kvm
