#!/bin/bash
#download apue-3e example,lib code and install apue lib and header files
#

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

tarf=src.3e.tar.gz
dir=apue.3e

pushd /usr/src
	curl -Ls http://www.apuebook.com/$tarf -o $tarf
	tar zxf $tarf
	gmake -C $dir/lib &&
		cp $dir/lib/libapue.a /usr/lib/. &&
		cp $dir/include/apue.h /usr/include/.
	gmake -C $dir/lib clean

	echo
	readlink -f $dir
	ls --color -l $dir
popd >/dev/null
