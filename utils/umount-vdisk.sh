#!/bin/bash

umount_vdisk2() {
	local fn=${FUNCNAME[0]}
	local CNT=$(sed -rn -e '/(loop-delete)/,/<\/action>/{/<allow_any>yes/p}' \
		/usr/share/polkit-1/actions/org.freedesktop.UDisks2.policy | wc -l)
	if [[ "$CNT" -lt 1 && $(id -u) -ne 0 ]]; then
		echo "{$fn:err} udisks2 policy does not support non-root user loop-delete yet" >&2
		return 1
	fi

	local mp=$1
	local mntinfo=$(mount | awk -v mp=$mp '$3 == mp {print $0}')
	if ! grep udisks2 <<<"$mntinfo"; then
		echo "{$fn:warn} $mp is not mounted by udisks2"
		return 1
	fi

	local mntdev=${mntinfo%% *}
	local lodev=${mntdev%p*}

	udisksctl unmount -b $mntdev
	udisksctl loop-delete -b $lodev
}

umount_vdisk2 "$@"
