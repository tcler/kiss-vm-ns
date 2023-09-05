#!/bin/bash

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

timeServer=clock.corp.redhat.com
host $timeServer|grep -q not.found: && timeServer=2.fedora.pool.ntp.org
TIME_SERVER=$timeServer

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

distro=${1:-9}
clientvm=${2:-rhel-client}
trun -tmux=- vm create -n $clientvm $distro -p 'vim bind-utils nfs-utils expect' --nointeract --saveimage -f

#-------------------------------------------------------------------------------
g_ontap_img_dir=/usr/share/Netapp-simulator
ontap_img_dir=$g_ontap_img_dir
[[ $(id -u) != 0 ]] && { ontap_img_dir=${ontap_img_dir//?usr?share/$HOME/Downloads}; }
mkdir -p $ontap_img_dir

#-------------------------------------------------------------------------------
#download/check ONTAP simulator image files
sver=${ONTAP_VER:-9.11.1}
verx=$(rpm -E %rhel)
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

echo -e "{INFO} check if Netapp ONTAP simulator image exist ..."
if is_rh_intranet; then
	rh_intranet=yes
	ImageUrl=http://download.devel.redhat.com/qa/rhts/lookaside/Netapp-Simulator/$ovaImage
	LicenseFileUrl=http://download.devel.redhat.com/qa/rhts/lookaside/Netapp-Simulator/$licenseFile
	curl-download.sh $ontap_img_dir/$ovaImage "$ImageUrl"
	curl-download.sh $ontap_img_dir/$licenseFile "$LicenseFileUrl"
fi
[[ -f "$ontap_img_dir/$ovaImage" && -f "$ontap_img_dir/$licenseFile" ]] || {
	if [[ -n "$rh_intranet" ]]; then
		echo "{Error} download '$ImageUrl' and/or '$LicenseFileUrl' fail" >&2
	else
		echo "{Error} ONTAP simulator image '$ImageUrl' and/or '$LicenseFileUrl' not found in '$ontap_img_dir'" >&2
	fi
	exit 1
}

#-------------------------------------------------------------------------------
#download ontap-simulator-in-kvm project
echo -e "{INFO} installing ontap-simulator-in-kvm tool ..."
targetdir=$HOME/Downloads
pjname=ontap-simulator-in-kvm
dirname=${pjname}
tarfpath=$targetdir/${pjname}.tar.gz
logf=/tmp/${pjname}.log
_url=https://github.com/tcler/ontap-simulator-in-kvm/archive/refs/heads/master.tar.gz
curl-download.sh $tarfpath "$_url"
extract.sh $tarfpath $HOME/Downloads $dirname
[[ -d "$targetdir/$dirname" ]] || {
	echo "{Error} download or extract '$tarfpath' fail" >&2
	exit 1
}

optx=(--time-server=$TIME_SERVER)
ONTAP_INSTALL_LOG=/tmp/ontap2-install.log
ONTAP_IF_INFO=/tmp/ontap2-if-info.txt
bash $targetdir/$dirname/$script --image $ontap_img_dir/$ovaImage --license-file $ontap_img_dir/$licenseFile "${optx[@]}" &> >(tee $ONTAP_INSTALL_LOG)
tac $ONTAP_INSTALL_LOG | sed -nr '/^[ \t]+lif/ {:loop /\nfsqe-[s2]nc1/!{N; b loop}; p;q}' | tac | tee  $ONTAP_IF_INFO

ONTAP_ENV_FILE=/tmp/ontap2info.env
source "$ONTAP_ENV_FILE"
trun     host $NETAPP_NAS_HOSTNAME
trun -x0 showmount -e "$NETAPP_NAS_IP_LOC"
vm exec -vx $clientvm -- showmount -e $NETAPP_NAS_IP
