#!/bin/bash
#autor: Jianhong Yin <yin-jianhong@163.com>
#function: get qemu-kvm cpu model expations by using qemu-qmp api. #just for fun

HostARCH=$(uname -m)
QEMU_KVM=$(PATH=/usr/libexec:$PATH command -v qemu-kvm 2>/dev/null)
availableHypervFlags() {
	local M=${1:-q35}
	local _hvfeatures=$(virsh domcapabilities --machine ${M:-q35} |
		sed -rn '/<hyperv supported=.yes/,/<\/hyperv>/{/ *<value>(.+)<\/value>/{s//\1/;p}}')

	#add dependent feature. why virsh domcapabilities does not show it/them
	grep -q 'stimer' <<<"$_hvfeatures" && _hvfeatures+=$'\ntime'

	local _hvflags=$(for _f in $_hvfeatures; do case ${_f} in (spinlocks) _f+==0x1fff;; (*) _f+==on;; esac; echo "hv-${_f}"; done | xargs)
	echo "${_hvflags// /,}"
}

subcmd=$1
machineType=${2:-${machineOpt%%,*}}
case $subcmd in
hvflag*) availableHypervFlags ${machineType%%,*}; exit;;
esac

if [[ -z "$cpuOpt" ]]; then
	hvflags=$(availableHypervFlags ${machineOpt%%,*})
	cpuOpt="host,${hvflags}"
fi
machineOpt="${machineOpt:-q35,accel=kvm}"
sessionName=qmpQueryCpuModel-$$
unixSocketPath=/tmp/${sessionName}.unix
qmpQueryCpuModelExpation() {
	local usock=$1
	while [[ ! -e ${usock} ]]; do sleep 1; done
	if command -v qmp-shell &>/dev/null; then
		local qmpshcmd="query-cpu-model-expansion type=full model={'name':'${cpuOpt%%,*}'}"
		qmp-shell -p ${usock} <<<"$qmpshcmd"
	else
		local pycmd=python; command -v $pycmd &>/dev/null || pycmd=python3
		local jsoncmd="{'execute': 'qmp_capabilities'}
			{'execute': 'query-cpu-model-expansion', 'arguments': {'model': {'name': '${cpuOpt%%,*}'}, 'type': 'full'}}"
		nc -U ${usock} <<<"$jsoncmd" | sed '1,2d' | $pycmd -m json.tool
	fi
}

viewCmd=cat
[[ -t 1 || ! -p /dev/stdout ]] && viewCmd=less
$viewCmd < <(
	tmux new -s ${sessionName} -d ${QEMU_KVM} -M ${machineOpt} -cpu ${cpuOpt} -nographic -qmp unix:${unixSocketPath},server,nowait
	qmpQueryCpuModelExpation ${unixSocketPath}
	tmux kill-session -t ${sessionName}
)
