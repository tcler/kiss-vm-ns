#!/bin/bash
# now linux doesn't support mount -t bind
# so here you are

export LANG=C
while read dst src others; do
	dev=${src%\[/*}
	rpath=${src##*\[/}; rpath=${rpath%]}
	rootdir=$(findmnt --list | awk -v dev=$dev '$2 == dev && $1 != "/" {print $1}')
	echo ${rootdir}/${rpath} $'\t' $dst $'\t' $dev $'\t' $others
done < <(findmnt --list  -o +PROPAGATION | awk '$2 ~ /\]$/')
