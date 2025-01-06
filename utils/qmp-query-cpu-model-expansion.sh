#!/bin/bash
#autor: Jianhong Yin <yin-jianhong@163.com>
#function: get qemu-kvm cpu model expations by using qemu-qmp api. #just for fun

HostARCH=$(uname -m)
QEMU_KVM=$(PATH=/usr/libexec:$PATH command -v qemu-kvm 2>/dev/null)
availableHypervFlags() {
	local hvflags=$(virt-install --features=? |
		awk -F. '/hyperv/{f=$2; print f}')
	hvflags=$(for _f in $hvflags "$@"; do [[ $_f = spinlocks ]] && _f+==0x1fff || _f+==on; echo hv-$_f; done | sort -u)
	for _flag in $hvflags; do
		sname=availableHyperv-$$
		tmux new -s ${sname} -d ${QEMU_KVM} -M ${machineOpt:-q35,accel=kvm} -cpu ${cpuOpt:-host,migratable=on},$_flag -nographic
		sleep 0.2
		if tmux ls 2>/dev/null | grep -q ${sname}; then
			echo "$_flag"
			tmux kill-session -t ${sname}
		fi
	done | paste -s -d,
}

althvflags="time relaxed vapic vpindex runtime synic syndbg stimer frequencies tlbflush ipi avic"
subcmd=$1
case $subcmd in
hvflag*) availableHypervFlags $althvflags; exit;;
esac

if [[ -z "$cpuOpt" ]]; then
	hvflags=$(availableHypervFlags $althvflags)
	cpuOpt="host,migratable=on,${hvflags}"
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
