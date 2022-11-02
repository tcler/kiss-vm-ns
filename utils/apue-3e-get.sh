#!/bin/bash
#download apue-3e example,lib code and install apue lib and header files
#

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -x $0 ]] || SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

tarf=src.3e.tar.gz
dir=apue.3e

pushd /usr/src
	wget http://www.apuebook.com/$tarf -O $tarf
	tar zxf $tarf
	make -C $dir/lib &&
		cp $dir/lib/libapue.a /usr/lib/. &&
		cp $dir/include/apue.h /usr/include/.
	make -C $dir/lib clean

	echo
	readlink -f $dir
	ls --color -l $dir
popd >/dev/null
