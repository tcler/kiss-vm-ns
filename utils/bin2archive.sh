#!/bin/bash
#archive a dynamic binary file with the libs
#just for fun and qemu-user test

[[ $# -eq 0 ]] && {
	echo -e "Usage: $0 <userspace-elf-program>"
	echo -e "Example:\n    $0 /usr/bin/ls"
	exit 1
}

bin=$1
_bin=$bin
[[ ! -e "${_bin}" && "${_bin}" != */* ]] && _bin=$(command -v "${_bin}")
[[ "$(file -b "$_bin" 2>/dev/null)" != ELF* ]] && {
	echo "{WARN} '${bin}' is not a binary file or not exist, quit."
	exit 1
}

get_slib_deps() {
	local bf=$1
	ldd "${bf}"|grep -Eo '/[^ ]+'
}

fname=${_bin##*/}
rootdir=root-$(uname -m)-${fname// /_}
slibfiles=$(get_slib_deps "${_bin}")
for file in $slibfiles; do
	mkdir -p "$rootdir${file%/*}"
	cp -v "$file" "$rootdir$file"
done
mkdir -p ${rootdir}/bin
cp -v "${_bin}" ${rootdir}/bin/

tar acf ${rootdir}.tar.gz ${rootdir}
rm -rf ${rootdir}
tar ztf ${rootdir}.tar.gz
