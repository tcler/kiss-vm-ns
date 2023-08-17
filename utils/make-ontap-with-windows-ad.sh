#!/bin/bash

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

export LANG=C
getDefaultNic() { ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'; }
getDefaultIp4() {
	local nic=$1 nics=
	[[ -z "$nic" ]] && nics=$(getDefaultNic)
	for nic in $nics; do
		[[ -z "$(ip -d link show  dev $nic|sed -n 3p)" ]] && { break; }
	done
	local ipaddr=$(ip addr show $nic)
	local ret=$(echo "$ipaddr" |
		awk '/inet .* (global|host lo)/{match($0,"inet ([0-9.]+)",M); print M[1]}')
	echo "$ret"
}

#-------------------------------------------------------------------------------
g_win_img_dir=/usr/share/windows-images
g_ontap_img_dir=/usr/share/Netapp-simulator
win_img_dir=$g_win_img_dir
ontap_img_dir=$g_ontap_img_dir
[[ $(id -u) != 0 ]] && {
	win_img_dir=${win_img_dir//?usr?share/$HOME/Downloads}
	ontap_img_dir=${ontap_img_dir//?usr?share/$HOME/Downloads}
}
run -debug mkdir -p $win_img_dir $ontap_img_dir

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

distro=${distro:-9}
rhelclnt=rhel-client
tmux new -d "vm create -n $rhelclnt $distro -p 'vim bind-utils nfs-utils expect' --nointeract --saveimage -f"

#-------------------------------------------------------------------------------
read A B C D N < <(getDefaultIp4|sed 's;[./]; ;g')
HostIPSuffix=$(printf %02x%02x $C $D)
HostIPSuffixL=$(printf %02x%02x%02x%02x $A $B $C $D)
winServer=win2022-${HostIPSuffix}

if true; then
#-------------------------------------------------------------------------------
#download/check Windows image files
WINVER=2022
os_variant=win2k22
win_img_name=Win2022-Evaluation.iso
openssh_file=OpenSSH-Win64.zip

echo -e "{INFO} check if Windows image files exist ..."
address="download.dev el.red hat.com"
BaseUrl=http://${address// /}/qa/rhts/lookaside
if is_rh_intranet; then
	rh_intranet=yes
	win_img_url="$BaseUrl/windows-images/$win_img_name"
	openssh_url="$BaseUrl/windows-images/$openssh_file"
	curl-download.sh $win_img_dir/$win_img_name "$win_img_url"
	curl-download.sh $win_img_dir/OpenSSH-Win64.zip "$openssh_url"
fi
if [[ ! -f "$win_img_dir/$win_img_name" || ! -f "$win_img_dir/$openssh_file" ]]; then
	if [[ -n "$rh_intranet" ]]; then
		echo "{Error} download '$win_img_name' and/or '$openssh_file' fail" >&2
	else
		echo "{Error} Windows image file '$win_img_name' and/or '$openssh_file' not found in '$win_img_dir'" >&2
	fi
	exit 1
fi

ADDomain=test${HostIPSuffix}.kissvm.net
ADPasswd=Sesame~0pen
vm create Windows-server -n ${winServer} -C $win_img_dir/$win_img_name --osv=$os_variant --dsize 50 \
	--win-auto=cifs-nfs --win-enable-kdc --win-openssh=$win_img_dir/$openssh_file \
	--win-domain=${ADDomain} --win-passwd=${ADPasswd} --wait --force
eval $(< /tmp/${winServer}.env)
[[ -z "$VM_INT_IP" || -z "$VM_EXT_IP" ]] && {
	echo "{ERROR} VM_INT_IP($VM_INT_IP) or VM_EXT_IP($VM_EXT_IP) of Windows VM is nil"
	exit 1
}
fi

#-------------------------------------------------------------------------------
#download/check ONTAP simulator image files
sver=${ONTAP_VER:-9.11.1}
verx=$(rpm -E %rhel)
[[ "$verx" = 7 ]] && sver=9.8

ovaImage=vsim-netapp-DOT${sver}-cm_nodar.ova
licenseFile=CMode_licenses_${sver}.txt
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

script=ontap-simulator-two-node.sh
eval $(< /tmp/${winServer}.env)
NTP_SERVER=10.5.26.10  #fixme
DNS_DOMAIN=${AD_DOMAIN}
DNS_ADDR=${VM_EXT_IP}
AD_HOSTNAME=${AD_FQDN}
AD_IP=${VM_EXT_IP}
AD_ADMIN=${ADMINUSER}
AD_PASS=${ADMINPASSWORD}
optx=(--ntp-server=$NTP_SERVER --dnsdomains=$DNS_DOMAIN --dnsaddrs=$DNS_ADDR \
	--ad-hostname=$AD_HOSTNAME --ad-ip=$AD_IP \
	--ad-admin=$AD_ADMIN --ad-passwd=$AD_PASS --ad-vm "${winServer}")
ONTAP_INSTALL_LOG=/tmp/ontap2-install.log
ONTAP_IF_INFO=/tmp/ontap2-if-info.txt
bash $targetdir/$dirname/$script --image $ontap_img_dir/$ovaImage --license-file $ontap_img_dir/$licenseFile "${optx[@]}" &> >(tee $ONTAP_INSTALL_LOG)

tac $ONTAP_INSTALL_LOG | sed -nr '/^[ \t]+lif/ {:loop /\nfsqe-[s2]nc1/!{N; b loop}; p;q}' | tac | tee $ONTAP_IF_INFO

################################# Assert ################################
echo -e "Assert 1: ping windows ad server: $VM_EXT_IP ..." >/dev/tty
ping -c 4 $VM_EXT_IP || {
	[[ -n "$VM_INT_IP" ]] && {
		vm exec $winServer -- ipconfig
	}
	echo -e "Alert 1: ping windows ad server($VM_EXT_IP) fail"
	exit 1
}
################################# Assert ################################

#join rhel-client to ad domain(krb5 realm)
echo -e "join $rhelclnt to $AD_DOMAIN($AD_HOSTNAME) ..."
netbiosname=host-${HostIPSuffix}
vm cpto -v $rhelclnt /usr/bin/config-ad-client.sh /usr/bin
vm exec -v $rhelclnt -- "echo '$netbiosname \$HOSTNAME' >/etc/host.aliases"
vm exec -v $rhelclnt -- "echo 'export HOSTALIASES=/etc/host.aliases' >>/etc/profile"
vm exec -v $rhelclnt -- "source /etc/profile;
	config-ad-client.sh --addc_ip $VM_INT_IP --addc_ip_ext $VM_EXT_IP -p $AD_PASS --config_krb --enctypes AES --host-netbios $netbiosname"
vm exec -vx $rhelclnt -- hostname -A
vm exec -vx $rhelclnt -- "hostname -A | grep -w $netbiosname"

#simple nfs krb5 mount test
ONTAP_ENV_FILE=/tmp/ontap2info.env
nfsmp_krb5=/mnt/nfsmp-ontap-krb5
nfsmp_krb5i=/mnt/nfsmp-ontap-krb5i
nfsmp_krb5p=/mnt/nfsmp-ontap-krb5p
source "$ONTAP_ENV_FILE"
vm exec -vx $rhelclnt -- mkdir -p $nfsmp_krb5 $nfsmp_krb5i $nfsmp_krb5p
vm exec -vx $rhelclnt -- mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5 -osec=krb5
vm exec -vx $rhelclnt -- mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5i -osec=krb5i
vm exec -vx $rhelclnt -- mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5p -osec=krb5p
vm exec -vx $rhelclnt -- mount -t nfs4
vm exec -vx $rhelclnt -- umount -a -t nfs4,nfs
vm exec -vx $rhelclnt -- "hostname -A | grep -w $netbiosname"
