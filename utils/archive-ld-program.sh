#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#Purpose:
# -Archive dynamic-linked prog and the library files it depends on and generate
#  a self-extract and runnable script that could be run on different platform.
# -Just for fun and qemu-user test

[[ $# -eq 0 ]] && {
	echo -e "Usage: $0 <userspace-elf-program>"
	echo -e "Example:\n\t$0  /usr/bin/ls\n\t$0  curl    #search in \$PATH if omitted"
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

progname=${_bin##*/}
progname=${progname// /_}
arch=$(uname -m)
rootdir=root-${arch}-${progname}
slibfiles=$(get_slib_deps "${_bin}")
for file in $slibfiles; do
	mkdir -p "$rootdir${file%/*}"
	cp -v "$file" "$rootdir$file"
done
mkdir -p ${rootdir}/bin
cp -v "${_bin}" ${rootdir}/bin/

ASH=${progname}.${arch}.ash
echo -e "#!/bin/bash\n\narch=${arch}; progname=${progname}; rootdir=${rootdir};\n" >${ASH}
cat <<\ASH >>${ASH}
command -v qemu-${arch} &>/dev/null || {
	echo "{Error} command 'qemu-${arch}' is required, please install package: qemu-user" >&2
	exit 2
}
tmpdir=$(mktemp -d)
tar -C ${tmpdir} -axf <(sed 1,/^#__end__/d $0)
qemu-${arch} -L ${tmpdir}/${rootdir} ${tmpdir}/${rootdir}/bin/${progname} "$@"; rc=$?
rm -rf ${tmpdir}
exit $rc
#__end__
ASH

tar acf - ${rootdir} >>${ASH} && rm -rf ${rootdir}
chmod +x ${ASH}
