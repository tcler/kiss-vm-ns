#!/bin/bash
#autor: Jianhong Yin <yin-jianhong@163.com>
#function: get qemu-kvm cpu model expations by using qemu-qmp api. #just for fun

HostARCH=$(uname -m)
QEMU_KVM=$(PATH=/usr/libexec:$PATH command -v qemu-kvm 2>/dev/null)

machineOpt="-M q35,accel=kvm"
sessionName=qmpQueryCpuModel-$$
unixSocketPath=/tmp/${sessionName}.unix
qmpQueryCpuModelExpation() {
	local usock=$1
	while [[ ! -e ${usock} ]]; do sleep 1; done
	if command -v qmp-shell &>/dev/null; then
		local qmpshcmd="query-cpu-model-expansion type=full model={'name':'${model:-host}'}"
		qmp-shell -p ${usock} <<<"$qmpshcmd"
	else
		local pycmd=python; command -v $pycmd &>/dev/null || pycmd=python3
		local jsoncmd="{'execute': 'qmp_capabilities'}
			{'execute': 'query-cpu-model-expansion', 'arguments': {'model': {'name': '${model:-host}'}, 'type': 'full'}}"
		nc -U ${usock} <<<"$jsoncmd" | sed '1,2d' | $pycmd -m json.tool
	fi
}

viewCmd=cat
[[ -t 1 || ! -p /dev/stdout ]] && viewCmd=less
$viewCmd < <(
	tmux new -s ${sessionName} -d ${QEMU_KVM} ${machineOpt} -nographic -qmp unix:${unixSocketPath},server,nowait
	qmpQueryCpuModelExpation ${unixSocketPath}
	tmux kill-session -t ${sessionName}
)
