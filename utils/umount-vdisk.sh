#!/bin/bash

umount_vdisk2() {
	local fn=${FUNCNAME[0]}
	local CNT=$(sed -rn -e '/(loop-delete)/,/<\/action>/{/<allow_any>yes/p}' \
		/usr/share/polkit-1/actions/org.freedesktop.??isks2.policy | wc -l)
	if [[ "$CNT" -lt 1 && $(id -u) -ne 0 ]]; then
		echo "{$fn:err} udisks2 policy does not support non-root user loop-delete yet" >&2
		[[ -z "$DISPLAY" ]] && return 1
	fi

	_umount_mp() {
		local _mp=$1
		local mntinfo=$(mount | grep -E "/dev/loop.* on ${mp} type")
		if ! grep udisks2 <<<"$mntinfo"; then
			echo "{$fn:warn} $_mp is not mounted by udisks2"
			return 1
		fi

		local mntdev=${mntinfo%% *}
		local lodev=${mntdev}
		[[ "$lodev" = /dev/loop[0-9]*p* ]] && lodev=${lodev%p*}

		udisksctl unmount -b $mntdev
		udisksctl loop-delete -b $lodev
	}

	local mp=$1
	if [[ ! -f "$mp" ]]; then
		_umount_mp $mp
	else
		local lodev= lodevs=
		lodevs=$(losetup -j $mp|awk -F: '{print $1}')
		for lodev in $lodevs; do
			local _mps _mp
			_mps=$(mount|awk "/^${lodev//\//.}(|p[0-9]+) /"'{print $3}')
			for _mp in $_mps; do
				_umount_mp $_mp
			done
		done
	fi
}

for mp; do
	mp=${mp%/}

	if [[ -f "${mp}" ]]; then
		umount_vdisk2 "${mp}"
	elif [[ -b "${mp}" ]]; then
		if mount | grep -E "^${mp} .*udisks2"; then
			mp=$(findmnt -nr -o target -S "${mp}"|sed 's/\\x20/ /g')
			umount_vdisk2 "${mp}"
		else
			cat <<-COMM >&2
				[WARN] device '${mp}' is not mounted by udisks2,
				 please try use 'sudo umount "${mp}"' directly
			COMM
		fi
	elif mountpoint -q "${mp}"; then
		if mount | grep -E "/dev/loop.* on ${mp} type .*udisks2"; then
			umount_vdisk2 "${mp}"
		elif mount | grep -E "/dev/fuse on ${mp} type"; then
			guestunmount "${mp}"
		fi
	else
		echo "[ERROR] dir '${mp}' is not a mountpoint" >&2
	fi
done
