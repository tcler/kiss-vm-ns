#!/bin/bash
#
switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

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
realm=${1:-IDM.JHTS.ORG}

case $OSV in
6|7)
	#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/linux_domain_identity_authentication_and_policy_guide/index#required-packages
	#yum install -y ipa-server ipa-server-dns   #IdM server with an integrated DNS
	yum install -y ipa-server                   #IdM server without an integrated DNS
	;;
8)
	#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/installing_identity_management/index#installing-packages-required-for-an-idm-server_preparing-the-system-for-ipa-server-installation
	umask 0022
	yum module enable -y idm:DL1
	yum distro-sync -y
	#yum module install -y idm:DL1/dns          #IdM server with an integrated DNS
	#yum module install -y idm:DL1/adtrust      #IdM server that has a trust agreement with Active Directory
	#yum module install -y idm:DL1/{dns,adtrust}
	yum module install -y idm:DL1/server        #IdM server without an integrated DNS
	umask 0027
	;;
9|*)
	#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/installing_identity_management/index#installing-packages-required-for-an-idm-server_preparing-the-system-for-ipa-server-installation
	umask 0022
	#yum install -y ipa-server ipa-server-trust-ad samba-client   #IdM server that has a trust agreement with Active Directory
	#yum install -y ipa-server ipa-server-dns   #IdM server with an integrated DNS
	yum install -y ipa-server                   #IdM server without an integrated DNS
	umask 0027
	;;
esac
