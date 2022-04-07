#!/bin/bash

vmname=$1
[[ -z "$vmname" ]] && exit 1

# Get install and ipconfig log
POST_INSTALL_LOGF=postinstall.log
IPCONFIG_LOGF=ipconfig.log
WIN_INSTALL_LOG=/tmp/$vmname.install.log
WIN_IPCONFIG_LOG=/tmp/$vmname.ipconfig.log
rm -f $WIN_INSTALL_LOG $WIN_IPCONFIG_LOG
vm cpfrom $vmname C:/$POST_INSTALL_LOGF $WIN_INSTALL_LOG
vm cpfrom $vmname C:/postinstall_logs/$IPCONFIG_LOGF $WIN_IPCONFIG_LOG
iconv -f UTF-16LE -t UTF-8 $WIN_INSTALL_LOG -o $WIN_INSTALL_LOG
dos2unix $WIN_INSTALL_LOG $WIN_IPCONFIG_LOG

# Save relative variables into a log file
VM_INT_IP=$(awk '/^ *IPv4 Address/ {if ($NF ~ /^192/) print $NF}' $WIN_IPCONFIG_LOG)
VM_EXT_IP=$(awk '/^ *IPv4 Address/ {if ($NF !~ /^(192|169.254)/) print $NF}' $WIN_IPCONFIG_LOG)
VM_EXT_IP6=$(awk '/^ *IPv6 Address/ {printf("%s,", $NF)}' $WIN_IPCONFIG_LOG)
[[ -z "$VM_EXT_IP" ]] && VM_EXT_IP=${VM_EXT_IP6%%,*}

VM_INFO_FILE=/tmp/$vmname.env
cat <<-EOF | tee $VM_INFO_FILE
	VM_INT_IP=$VM_INT_IP
	VM_EXT_IP=$VM_EXT_IP
	VM_EXT_IP6=$VM_EXT_IP6

	WIN_CIFS_SHARE1=cifstest
	WIN_CIFS_SHARE2=cifssch
	WIN_DFS_SHARE=dfsroot
	WIN_DFS_SHARE1=dfsroot/local
	WIN_DFS_SHARE2=dfsroot/remote
	WIN_NFS_SHARE1=/nfstest
	WIN_NFS_SHARE2=/nfssch
EOF
