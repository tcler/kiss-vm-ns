#!/bin/bash
#
shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

if ! { command -v yum &>/dev/null || command -v dnf &>/dev/null; }; then
	echo "{WARN} OS is not supported."
	exit 1
fi

OSV=$(rpm -E %rhel)
if [[ $OSV != %rhel && $OSV -lt 6 ]]; then
	echo "{WARN} RHEL-5 or early version does not support ipa-server."
	exit 1
fi

switchroot "$@"
yOpt="-q --nobest"
[[ $OSV -gt 7 ]] && yOpt+=" --allowerasing"

echo "{INFO} installing ipa-server ..."
#fedora
if [[ "$OSV" =~ %rhel ]]; then
	dnf install -y $yOpt freeipa-server freeipa-server-dns  #IdM server with an integrated DNS
#rhel/centos/rocky/alma/...
else
	case $OSV in
	6|7)
		yOpt="-q"
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/linux_domain_identity_authentication_and_policy_guide/index#required-packages
		#yum install -y $yOpt ipa-server                #IdM server without an integrated DNS
		yum install -y $yOpt ipa-server ipa-server-dns  #IdM server with an integrated DNS
		;;
	8)
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/installing_identity_management/index#installing-packages-required-for-an-idm-server_preparing-the-system-for-ipa-server-installation
		umask 0022
		yum module enable -y idm:DL1
		yum distro-sync -y
		#yum module install -y $yOpt idm:DL1/server     #IdM server without an integrated DNS
		#yum module install -y $yOpt idm:DL1/adtrust    #IdM server that has a trust agreement with Active Directory
		#yum module install -y $yOpt idm:DL1/{dns,adtrust}
		yum module install -y $yOpt idm:DL1/dns         #IdM server with an integrated DNS
		umask 0027
		;;
	9|*)
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/installing_identity_management/index#installing-packages-required-for-an-idm-server_preparing-the-system-for-ipa-server-installation
		umask 0022
		#yum install -y $yOpt ipa-server ipa-server-trust-ad samba-client   #IdM server that has a trust agreement with Active Directory
		#yum install -y $yOpt ipa-server                #IdM server without an integrated DNS
		yum install -y $yOpt ipa-server ipa-server-dns  #IdM server with an integrated DNS
		umask 0027
		;;
	esac
fi
