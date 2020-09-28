#!/bin/bash

Usage() {
	echo "$0 [lvm2 device] [-n]"
}

vglist() {
        local dev=("$@")
        #why there isn't vg_active field?
        pvs -o vg_name,vg_uuid,lv_active --noheading "${dev[@]}"|uniq
}

_at=`getopt -o hn \
	--long help \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-n)        RenameDuplicateName=no; shift 1;;
	--) shift; break;;
	esac
done

#rename vgname if there are volume groups with same names
[[ "$RenameDuplicateName" != no ]] && {
	while read head vgs; do
		for vg in $vgs; do
			vgrename -v $vg ${head}-$((++i))
		done
	done < <(vglist | awk '!/active$/ {a[$1]++; b[$1]=b[$1] FS $2; } END {for(vg in a) if (a[vg]>1) print vg, b[vg]}')
}

vglist "$@"
