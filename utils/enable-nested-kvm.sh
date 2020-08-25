#!/bin/bash

enable_nested_kvm() {
	local kmodule=$(lsmod|awk '$1 == "kvm" {print $NF}')
	local vendor=${kmodule#kvm_}

	{
	echo "options kvm-$vendor nested=1"

	[[ "$vendor" = intel ]] && cat <<-EOF
	options kvm-$vendor enable_shadow_vmcs=1
	options kvm-$vendor enable_apicv=1
	options kvm-$vendor ept=1
	EOF
	} | sudo tee /etc/modprobe.d/kvm-nested.conf >/dev/null

	if [[ $(< /sys/module/$kmodule/parameters/nested) != [Yy1] ]]; then
		modprobe -r $kmodule || {
			echo -e "{WARN} stop tasks are using module $kmodule, and try again"
			return 1
		}
		modprobe $kmodule
	fi
	cat /sys/module/$kmodule/parameters/nested
}
enable_nested_kvm
