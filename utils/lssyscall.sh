#!/bin/bash

Arch=$(arch)

ausyscall() {
	if [[ $# = 0 ]]; then
		command ausyscall --dump | awk '{print $2, $1, "local"}'
	else
		local call=$1
		local num=$call
		local name=
		read name num < <(command ausyscall $Arch $call 2>/dev/null)
		if [[ -n "$name" ]]; then
			if [[ -n "$num" ]]; then
				echo $name $num local
			else
				echo $name $call local
			fi
		else
			return 1
		fi
	fi
}

lsyscall() {
	local tableurl=https://raw.githubusercontent.com/hrw/syscalls-table/master/tables
	is_available_url() { curl --connect-timeout 8 -m 16 --output /dev/null --silent --head --fail $1 &>/dev/null; }
	is_intranet() { is_available_url http://download.devel.redhat.com; }
	is_intranet && tableurl=http://download.devel.redhat.com/qa/rhts/lookaside/syscalls-table/tables

	local tablefurl=$tableurl/syscalls-${Arch}
	local tables=$(curl -s -L $tablefurl | sort -n -k2)

	if [[ $# = 0 ]]; then
		awk '{
			if ($2 != "")
				print($1, $2, "upstream")
			else
				print($1, "nil", "upstream")
			fi
		}' <<<"$tables"
	else
		local call=$1
		awk -v call=$call '
		$1 == call || $2 == call {
			if ($2 != "")
				print($1, $2, "upstream")
			else
				print($1, "nil", "upstream")
			fi
		}' <<<"$tables"
	fi
}

Usage() {
	echo "$0 [-h] [-a|-u] [arch] [syscall name | syscall num]"
}

syscalls=()
for arg; do
	case "$arg" in
	-h)    Usage; exit;;
	-a|-u) ALL=yes;;
	-*)    echo "{WARN} unkown option '${arg}'" >&2;;
	*)     syscalls+=($arg);;
	esac
done
set -- "${syscalls[@]}"

case $1 in
alpha|arc|arm|arm64|armoabi|avr32|blackfin|c6x|cris|csky|frv|h8300|hexagon|i386|ia64|m32r|m68k|metag|microblaze|mips64|mips64n32|mipso32|mn10300|nds32|nios2|openrisc|parisc|powerpc|powerpc64|riscv32|riscv64|s390|s390x|score|sh|sh64|sparc|sparc64|tile|tile64|unicore32|x32|x86_64|xtensa)
	Arch=$1; shift;;
ppc|ppc64|ppc64le)
	Arch=${Arch/ppc/powerpc}; Arch=${Arch%le}; shift;;
esac

if [[ "${#}" = 0 ]]; then
	if [[ "$ALL" = yes ]]; then
		lsyscall
	else
		ausyscall
	fi
else
	ausyscall "$1" || lsyscall "$1"
fi
