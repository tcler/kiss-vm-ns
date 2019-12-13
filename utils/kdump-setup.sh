#!/bin/bash
# author: yin-jianhong@163.com
#
# ref: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/kernel_administration_guide/kernel_crash_dump_guide#sect-kdump-memory-requirements
# ref: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/kernel_administration_guide/kernel_crash_dump_guide#sect-kdump-memory-thresholds

LANG=C

[[ $(id -u) != 0 ]] && {
	echo -e "{Warn} configure kdump need root permission, try:\n  sudo $0 ..." >&2
	exec sudo $0 "$@"
}

#phase0: check/install kexec-tools
#----------------------------------
rpm -q kexec-tools || yum install -y kexec-tools
echo

#phase1: show/fix image type
#----------------------------------
grep ^KDUMP_IMG= /etc/sysconfig/kdump
echo

#phase2: reserve memory
#----------------------------------
kver=$(uname -r|awk -F. '{print $1}')
mgsize=$(free -gt | awk '/^Mem/{print $2}')
mmsize=$(free -mt | awk '/^Mem/{print $2}')

#RHEL-8
if [[ $kver -ge 4 ]]; then
	val=auto
	[[ ${mmsize} -lt 960 ]] && val=64M
#RHEL-7
elif [[ $kver -eq 3 ]]; then
	if [[ ${mgsize} -ge 4 ]]; then
		val=auto
	elif [[ ${mgsize} -ge 2 ]]; then
		if [[ $(arch) = s390* ]]; then
			val="161M"
		else
			val=auto
		fi
	else
		val="0M-960M:64M,960M-2G:128M"
	fi
else
	echo "{WARN} don't support kernel older then kernel-3"
	exit 1
fi

echo grubby --args="crashkernel=${val}" --update-kernel="$(/sbin/grubby --default-kernel)"
grubby --args="crashkernel=${val}" --update-kernel="$(/sbin/grubby --default-kernel)"

# hack /usr/bin/kdumpctl: add 'chmod a+r corefile'
sed 's;mv $coredir/vmcore-incomplete $coredir/vmcore;&\nchmod a+r $coredir/vmcore;' /usr/bin/kdumpctl -i

#phase3: enable kdump and reboot
#----------------------------------
systemctl enable kdump.service
[[ "$1" = reboot ]] && reboot
