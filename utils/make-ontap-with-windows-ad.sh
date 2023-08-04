#!/bin/bash

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

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

export LANG=C
[[ $(id -u) != 0 ]] && {
	sudo -K
	while true; do
		read -s -p "sudo Password: " password
		echo
		echo "$password" | sudo -S ls / >/dev/null && break
	done
}

#-------------------------------------------------------------------------------
win_img_dir=/usr/share/windows-images
ontap_img_dir=/usr/share/Netapp-simulator
[[ $(id -u) != 0 ]] && {
	win_img_dir=${win_img_dir//?usr?share/$HOME/Downloads}
	ontap_img_dir=${ontap_img_dir//?usr?share/$HOME/Downloads}
}
mkdir -p $win_img_dir $ontap_img_dir

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

echo -e "{INFO} creating macvlan if mv-host-pub ..."
echo "$password" | sudo -S netns host,mv-host-pub,dhcp
ip a s dev mv-host-pub

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
	curl -k -Ls "$win_img_url" -o $win_img_dir/$win_img_name
	curl -k -Ls "$openssh_url" -o $win_img_dir/OpenSSH-Win64.zip
fi
[[ -f "$win_img_dir/$win_img_name" && -f "$win_img_dir/$openssh_file" ]] || {
	if [[ -n "$rh_intranet" ]]; then
		echo "{Error} download '$win_img_name' and/or '$openssh_file' fail" >&2
	else
		echo "{Error} Windows image file '$win_img_name' and/or '$openssh_file' not found in '$win_img_dir'" >&2
	fi
	exit 1
fi

ADDomain=fsqe${HostIPSuffix}.redhat.com
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

#-------------------------------------------------------------------------------
#download ontap-simulator-in-kvm project
echo -e "{INFO} installing ontap-simulator-in-kvm tool ..."
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

script=ontap-simulator-two-node.sh
eval $(< /tmp/${winServer}.env)
NTP_SERVER=10.5.26.10
DNS_DOMAIN=${AD_DOMAIN}
DNS_ADDR=${VM_EXT_IP}
AD_HOSTNAME=${AD_FQDN}
AD_IP=${VM_EXT_IP}
AD_ADMIN=${ADMINUSER}
AD_PASS=${ADMINPASSWORD}
optx=(--ntp-server=$NTP_SERVER --dnsdomains=$DNS_DOMAIN --dnsaddrs=$DNS_ADDR \
	--ad-hostname=$AD_HOSTNAME --ad-ip=$AD_IP \
	--ad-admin=$AD_ADMIN --ad-passwd=$AD_PASS --ad-ip-hostonly "${VM_INT_IP}")
ONTAP_INSTALL_LOG=/tmp/ontap2-install.log
ONTAP_IF_INFO=/tmp/ontap2-if-info.txt
bash $dirname/$script --image $ontap_img_dir/$ovaImage --license-file $ontap_img_dir/$licenseFile "${optx[@]}" &> >(tee $ONTAP_INSTALL_LOG)

tac $ONTAP_INSTALL_LOG | sed -nr '/^[ \t]+lif/ {:loop /\nfsqe-[s2]nc1/!{N; b loop}; p;q}' | tac | tee $ONTAP_IF_INFO

################################# Assert ################################
echo -e "Assert 1: ping windows ad server: $VM_EXT_IP ..." >/dev/tty
ping -c 4 $VM_EXT_IP || {
	[[ -n "$VM_INT_IP" ]] && {
		sshOpt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
		expect -c "set timeout 120
		spawn ssh $sshOpt $AD_ADMIN@${VM_INT_IP} ipconfig
		expect {password:} { send \"${AD_PASSWD}\\r\" }
		"
	}
	echo -e "Alert 1: ping windows ad server($VM_EXT_IP) fail"
	exit 1
}
################################# Assert ################################

#join host to ad domain(krb5 realm)
echo -e "join host to $AD_DOMAIN($AD_HOSTNAME) ..."
netbiosname=host-${HostIPSuffix}
 echo "$netbiosname $HOSTNAME" >/etc/host.aliases
 echo "export HOSTALIASES=/etc/host.aliases" >>/etc/profile
 source /etc/profile
config-ad-client.sh --addc_ip $VM_INT_IP --addc_ip_ext $VM_EXT_IP -p $AD_PASS --config_krb --enctypes AES --host-netbios $netbiosname

ONTAP_ENV_FILE=/tmp/ontap2info.env
nfsmp_krb5=/mnt/nfsmp-ontap-krb5
nfsmp_krb5i=/mnt/nfsmp-ontap-krb5i
nfsmp_krb5p=/mnt/nfsmp-ontap-krb5p
eval $(< $ONTAP_ENV_FILE)
clientip=$(getDefaultIp4 mv-host-pub)

################################# Assert ################################
echo -e "Assert 2: ping windows ad server: $VM_EXT_IP ..." >/dev/tty
ping -c 4 $VM_EXT_IP || {
	[[ -n "$VM_INT_IP" ]] && {
		sshOpt="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
		expect -c "set timeout 120
		spawn ssh $sshOpt $AD_ADMIN@${VM_INT_IP} ipconfig
		expect {password:} { send \"${AD_PASSWD}\\r\" }
		"
	}
	echo -e "Alert 2: ping windows ad server($VM_EXT_IP) fail"
	exit 1
}
################################# Assert ################################

echo -e "\nhostname -A ..."
hostname -A

echo -e "\nhostname $netbiosname  #required by nfs krb5 mount ..."
hostname $netbiosname  #required by nfs krb5 mount

echo -e "\nnfs mount test ..."
echo $password | sudo -S bash -c "
. /usr/lib/bash/libtest
run mkdir -p $nfsmp_krb5 $nfsmp_krb5i $nfsmp_krb5p
run mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5 -osec=krb5,clientaddr=$clientip
run mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5i -osec=krb5i,clientaddr=$clientip
run mount $NETAPP_NAS_HOSTNAME:$NETAPP_NFS_SHARE2 $nfsmp_krb5p -osec=krb5p,clientaddr=$clientip
run mount -t nfs4
run umount -a -t nfs4,nfs
"
