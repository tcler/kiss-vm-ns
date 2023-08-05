#!/bin/bash

## argparse
P=${0##*/}
Usage() {
	echo "Usage: $P <compressed-file> [targetdir] [topdirname] [--path]"
	echo "  e.g: $P /path/to/kernel-src.tar.gz /usr/src kernel-devel"
	echo "  e.g: $P /path/to/kernel-src.tar.gz /usr/src kernel-doc --path=Documentation/*"
}
_at=`getopt -o hp: \
	--long help \
	--long path: \
    -a -n '$P' -- "$@"`
eval set -- "$_at"

folders=
while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-p|--path)      folders="$2"; shift 2;;
	--) shift; break;;
	esac
done

[[ $# = 0 ]] && {
	Usage >&2
	exit 1
}

compressedFile=$1
[[ -f "$compressedFile" ]] || {
	echo "{Error} file '$compressedFile' not found." >&2
	exit 2
}
targetdir=${2:-.}
[[ -d "$targetdir" ]] || mkdir -p "$targetdir" ||
[[ -d "$targetdir" ]] || {
	echo "{Error} file '$targetdir' created fail, please theck permission" >&2
	exit 2
}
topdir=$3

filetype=$(file -b ${compressedFile})
_targetdir=$targetdir
if [[ "$filetype" = Zip* ]]; then
	otopdir=($(unzip -Z1 $filepath | awk -F/ '{a[$1]++} END { for(key in a) { print(key) } }'))
	[[ -z "$otopdir" ]] && { echo "{error} extract $compressedFile fail" >&2; exit 3; }
	[[ "${#otopdir[@]}" -gt 1 ]] && {
		otopdir=; [[ -n "$topdir" ]] && _targetdir+=/$topdir; topdir=
		[[ "$_targetdir" != $targetdir ]] && { mkdir -p $_targetdir; }
	}
	unzip "$compressedFile" $folders -d $_targetdir &>/dev/null
else
	case "$filetype" in
		(gzip*) xtype=z;;
		(bzip2*) xtype=j;;
		(XY*) xtype=J;;
		(*) xtype=a;;
	esac
	otopdir=($(tar taf ${compressedFile} | awk -F/ '{a[$1]++} END { for(key in a) { print(key) } }'))
	[[ -z "$otopdir" ]] && { echo "{error} extract $compressedFile fail" >&2; exit 3; }
	[[ "${#otopdir[@]}" -gt 1 ]] && {
		otopdir=; [[ -n "$topdir" ]] && _targetdir+=/$topdir; topdir=
		[[ "$_targetdir" != $targetdir ]] && { mkdir -p $_targetdir; }
	}
	_cmd="tar -C $_targetdir -${xtype}xf ${compressedFile} $folders"   #--strip-components=1
	echo "{run} $_cmd" >&2
	eval $_cmd
fi
[[ -d "$_targetdir/${otopdir}" ]] || {
	echo "{Error} extract to '$_targetdir' fail, please theck permission" >&2
	exit 1
}
[[ -n "$topdir" && "${topdir}" != "$otopdir" ]] && {
	_cmd="mv $_targetdir/${otopdir} $_targetdir/$topdir"
	echo "{run} $_cmd" >&2
	eval $_cmd
}
