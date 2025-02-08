#!/bin/bash
#
shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }

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
yOpt="-q"

echo "{INFO} installing ipa-client ..."
#fedora
if [[ "$OSV" =~ %rhel ]]; then
	dnf install -y -q freeipa-client
#rhel/centos/rocky/alma/...
else
	case $OSV in
	6|7)
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/linux_domain_identity_authentication_and_policy_guide/index#client-automatic-required-packages
		yum install -y $yOpt ipa-client
		;;
	8)
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/installing_identity_management/index#installing-idm-client-packages-from-the-idm-dl1-stream_preparing-the-system-for-ipa-client-installation
		yum module enable -y idm:DL1
		yum distro-sync -y
		yum module install -y $yOpt idm:DL1/client
		;;
	9|*)
		#https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/installing_identity_management/index#assembly_installing-an-idm-client_installing-identity-management
		yum install -y $yOpt ipa-client
		;;
	esac
fi
