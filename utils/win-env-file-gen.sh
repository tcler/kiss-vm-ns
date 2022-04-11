#!/bin/bash

vmname=$1
[[ -z "$vmname" ]] && exit 1

VM_ENV_FILE=/tmp/$vmname.env
echo "[INFO] generating windows env file: $VM_ENV_FILE"

# Get install and ipconfig log
POST_INSTALL_LOGF=postinstall.log
IPCONFIG_LOGF=ipconfig.log
WIN_INSTALL_LOG=/tmp/$vmname.install.log
WIN_IPCONFIG_LOG=/tmp/$vmname.ipconfig.log
WIN_ENVF=/tmp/win.env.$vmname
rm -f $WIN_INSTALL_LOG $WIN_IPCONFIG_LOG $WIN_ENVF
vm cpfrom $vmname C:/$POST_INSTALL_LOGF $WIN_INSTALL_LOG
vm cpfrom $vmname C:/postinstall_logs/$IPCONFIG_LOGF $WIN_IPCONFIG_LOG
vm cpfrom $vmname C:/win.env $WIN_ENVF
iconv -f UTF-16LE -t UTF-8 $WIN_INSTALL_LOG -o $WIN_INSTALL_LOG
dos2unix $WIN_INSTALL_LOG $WIN_IPCONFIG_LOG $WIN_ENVF

# Save relative variables into a log file
VM_INT_IP=$(awk '/^ *IPv4 Address/ {if ($NF ~ /^192/) print $NF}' $WIN_IPCONFIG_LOG)
VM_EXT_IP=$(awk '/^ *IPv4 Address/ {if ($NF !~ /^(192|169.254)/) print $NF}' $WIN_IPCONFIG_LOG)
VM_EXT_IP6=$(awk '/^ *IPv6 Address/ {printf("%s,", $NF)}' $WIN_IPCONFIG_LOG)
[[ -z "$VM_EXT_IP" ]] && VM_EXT_IP=${VM_EXT_IP6%%,*}

cat $WIN_ENVF - <<-EOF | tee $VM_ENV_FILE

	VM_INT_IP=$VM_INT_IP
	VM_EXT_IP=$VM_EXT_IP
	VM_EXT_IP6=$VM_EXT_IP6
EOF
