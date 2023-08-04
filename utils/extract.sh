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
if [[ "$filetype" = Zip* ]]; then
	otopdir=$(unzip -Z1 $filepath | sed '1{p;q}')
	[[ -z "$otopdir" ]] && { echo "{error} extract $compressedFile fail" >&2; exit 3; }
	unzip "$compressedFile" -d $targetdir &>/dev/null
else
	case "$filetype" in
		(gzip*) xtype=z;;
		(bzip2*) xtype=j;;
		(XY*) xtype=J;;
		(*) xtype=a;;
	esac
	otopdir=$(tar taf ${compressedFile} | sed -n '1{s@/$@@;p;q}')
	[[ -z "$otopdir" ]] && { echo "{error} extract $compressedFile fail" >&2; exit 3; }
	tar -C $targetdir -${xtype}xf ${compressedFile} #--strip-components=1
fi
[[ -n "$topdir" && "${topdir}" != "$otopdir" ]] && mv $targetdir/${otopdir} $targetdir/$topdir
