#!/bin/bash

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

#-------------------------------------------------------------------------------
ontap_img_dir=/usr/share/Netapp-simulator
sudo bash -c "mkdir -p $ontap_img_dir && chmod o+rw $ontap_img_dir"

verx=$(rpm -E %rhel)
sver=${ONTAP_VER:-9.11.1}
[[ "$verx" = 7 ]] && sver=9.8

ovaImage=vsim-netapp-DOT${sver}-cm_nodar.ova
licenseFile=CMode_licenses_${sver}.txt
script=ontap-simulator-two-node.sh
minram=$((15*1000))
ramsize=$(free -m|awk '/Mem:/{print $2}')
[[ "$ramsize" -le "$minram" ]] && {
	echo "{WARN} total ram size(${ramsize}m) on your system is not enough(>=$minram)" >&2
	exit 1
}

#download ONTAP simulator image files
if is_rh_intranet; then
	rh_intranet=yes
	ImageUrl=http://download.devel.redhat.com/qa/rhts/lookaside/Netapp-Simulator/$ovaImage
	LicenseFileUrl=http://download.devel.redhat.com/qa/rhts/lookaside/Netapp-Simulator/$licenseFile
	curl -k -Ls "$ImageUrl" -o $ontap_img_dir/$ovaImage
	curl -k -Ls "$LicenseFileUrl" -o $ontap_img_dir/$licenseFile
fi
[[ -f "$ontap_img_dir/$ovaImage" && -f "$ontap_img_dir/$licenseFile" ]] || {
	if [[ -n "$rh_intranet" ]]; then
		echo "{Error} download '$ImageUrl' and/or '$LicenseFileUrl' fail" >&2
	else
		echo "{Error} ONTAP simulator image '$ImageUrl' and/or '$LicenseFileUrl' not found in '$ontap_img_dir'" >&2
	fi
	exit 1
}

#download ontap-simulator-in-kvm project
pjname=ontap-simulator-in-kvm
dirname=${pjname}
tarf=${pjname}.tar.gz
logf=${pjname}.log
_url=https://github.com/tcler/ontap-simulator-in-kvm/archive/refs/heads/master.tar.gz
curl -k -Ls "$_url" -o $tarf
extract.sh $tarf . $dirname
[[ -d "$dirname" ]] || {
	echo "{Error} download or extract '$tarf' fail" >&2
	exit 1
}

bash $dirname/$script --image $ontap_img_dir/$ovaImage --license-file $ontap_img_dir/$licenseFile "$@" &> >(tee $logf)
tac $logf | sed -nr '/^[ \t]+lif/ {:loop /\nfsqe-[s2]nc1/!{N; b loop}; p;q}' | tac | tee ontap-if-info.txt
