#!/bin/bash

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

yum install -y autoconf gcc make netpbm-progs
git clone https://github.com/tcler/gocr
(
cd gocr
./configure && make && make install
)
