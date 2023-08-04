#!/bin/bash
[[ $# = 0 ]] && {
	echo "{Usage} $0 <compressed-file> [targetdir] [topdirname]" >&2
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
	unzip "$compressedFile" -d $_targetdir &>/dev/null
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
	tar -C $_targetdir -${xtype}xf ${compressedFile} #--strip-components=1
fi
[[ -d "$_targetdir/${otopdir}" ]] || {
	echo "{Error} extract to '$_targetdir' fail, please theck permission" >&2
	exit 1
}
[[ -n "$topdir" && "${topdir}" != "$otopdir" ]] && mv $_targetdir/${otopdir} $_targetdir/$topdir
