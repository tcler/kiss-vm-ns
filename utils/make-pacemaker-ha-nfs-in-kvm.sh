#!/bin/bash
# author: Jianhong Yin <yin-jianhong@163.com>
# build a simple pacemaker ha nfs server env in libvirt/KVM
#
# REF:
# - https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_high_availability_clusters/assembly_configuring-active-passive-nfs-server-in-a-cluster-configuring-and-managing-high-availability-clusters
# - https://atl.kr/dokuwiki/doku.php/rhel8_cluster_%EA%B5%AC%EC%84%B1
# - deepseek
#
# Verified: [RHEL-8, RHEL-9, RHEL-10, Fedira-43, Fedora-44]
# `- don't support RHEL-7 and before

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

Usage() {
	cat <<-EOF
	Usage:
	  sudo $P [options] <distro-(name|pattern)> [-- vm-create-options]

	Options:
	  -h, -help              ; show this help
	EOF
}

_at=$(getopt -a -o h \
	--long help \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	--) shift; break;;
	esac
done
[[ $# = 0 ]] && { Usage >&2; exit 1; }
distro=$1; shift

export LANG=C

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

#-------------------------------------------------------------------------------
#create VMs for iSCSI-server,ha-node01,ha-node02
iscsiServ=ha-iscsi-server
node1=ha-node01
node2=ha-node02
haclnt=ha-client
nodepkgs=vim,tmux,iscsi-initiator-utils,pacemaker,fence-agents-scsi,watchdog,pcs,pcp-zeroconf,nfs-utils #,lvm2-lockd,dlm
servpkgs=vim,tmux,targetcli
clntpkgs=vim,tmux,nfs-utils

trun -tmux=$haclnt-$$    vm create -f -n $haclnt $distro --nointeract -p $clntpkgs --net=kissaltnet $@
trun -tmux=$iscsiServ-$$ vm create -f -n $iscsiServ $distro --nointeract -p $servpkgs --net=kissaltnet --xdisk=40 $@
trun -tmux=$node1-$$     vm create -f -n $node1 $distro --nointeract -p $nodepkgs --net=kissaltnet $@
trun                     vm create -f -n $node2 $distro --nointeract -p $nodepkgs --net=kissaltnet $@
while tmux ls | grep -E "($iscsiServ|$node1|$haclnt)"-$$; do sleep 5; done

#-------------------------------------------------------------------------------
#configure iscsi server and client
## stop firewalld
for vmn in $iscsi $node1 $node2; do vm exec $vmn -- 'systemctl disable firewalld --now 2>/dev/null'; done

## start server/service
vm exec $iscsiServ -- systemctl enable target --now
vm exec $node1 -- systemctl enable iscsid --now
vm exec $node2 -- systemctl enable iscsid --now

## create block and iscsi
vm exec -v $iscsiServ -- targetcli /backstores/block/ create share_disk /dev/vdb
vm exec -v $iscsiServ -- targetcli /iscsi/ create
vm exec -v $iscsiServ -- targetcli /backstores/block/ ls
vm exec -v $iscsiServ -- targetcli /iscsi/ ls

## get initIQN of clients
initIQN01=$(vm exec $node1 -- cat /etc/iscsi/initiatorname.iscsi|awk -F= '{print $2}')
initIQN02=$(vm exec $node2 -- cat /etc/iscsi/initiatorname.iscsi|awk -F= '{print $2}')

## add targetIQN/ACLs
targetIQN=$(vm exec $iscsiServ -- targetcli /iscsi/ ls|grep -o 'iqn\.[^ ]*')
vm exec -v $iscsiServ -- targetcli /iscsi/$targetIQN/tpg1/acls/ create $initIQN01
vm exec -v $iscsiServ -- targetcli /iscsi/$targetIQN/tpg1/acls/ create $initIQN02

## create targetIQN/LUN
vm exec -v $iscsiServ -- targetcli /iscsi/$targetIQN/tpg1/luns/ create /backstores/block/share_disk

## save config and show
vm exec -v $iscsiServ -- targetcli saveconfig
vm exec -v $iscsiServ -- targetcli ls

## discovery/login at nodes
read iscsiServIp _ < <(vm ifaddr $iscsiServ)
for node in $node1 $node2; do
	vm exec -v $node -- sed -ir '/.*system_id_source.=.*/s//system_id_source = "uname"/' /etc/lvm/lvm.conf
	vm exec -v $node -- iscsiadm -m discovery -t st -p $iscsiServIp
	vm exec -v $node -- iscsiadm -m node -T $targetIQN -p $iscsiServIp -l
	vm exec -v $node -- iscsiadm -m node -T $targetIQN -p $iscsiServIp --op update -n node.startup -v automatic
	vm exec -v $node -- lsblk
	: vm exec -v $node -- systemctl enable dlm --now
	: vm exec -v $node -- systemctl enable lvmlockd --now
done

#-------------------------------------------------------------------------------
#Configure SCSI-3 Persistent Reservation support (required for fence_scsi)
vm exec -v $node1 -- "echo 'options scsi_mod dev_flags=$initIQN01:0x0' >/etc/modprobe.d/scsi-pr.conf"
vm exec -v $node1 -- dracut -f
vm exec -v $node2 -- "echo 'options scsi_mod dev_flags=$initIQN02:0x0' >/etc/modprobe.d/scsi-pr.conf"
vm exec -v $node2 -- dracut -f

#-------------------------------------------------------------------------------
#Configure watchdog (required by Pacemaker)
for node in $node1 $node2; do
	vm exec -v $node -- "echo 'softdog' >>/etc/modules-load.d/watchdog.conf"
	vm exec -v $node -- modprobe softdog
	vm exec -v $node -- systemctl enable watchdog --now
	vm exec -v $node -- systemctl status watchdog --no-pager
done

#-------------------------------------------------------------------------------
#Configure Pacemaker cluster
## Set up hostname resolution(simplified, using /etc/hosts) and enable pcsd
read node1Ip < <(vm ifaddr $node1)
read node2Ip < <(vm ifaddr $node2)
for node in $node1 $node2; do
	vm exec -v $node -- "echo '$iscsiServIp $iscsiServ' >>/etc/hosts"
	vm exec -v $node -- "echo '$node1Ip $node1' >>/etc/hosts"
	vm exec -v $node -- "echo '$node2Ip $node2' >>/etc/hosts"
	vm exec -v $node -- systemctl enable pcsd --now
	vm exec -v $node -- 'echo hacluster:redhat123 | chpasswd'
done

## Create cluster on node1
vm exec -v $node1 -- pcs host auth $node1 $node2 -u hacluster -p redhat123
vm exec -v $node1 -- pcs cluster setup nfs-cluster $node1 $node2
vm exec -v $node1 -- pcs cluster start --all
vm exec -v $node1 -- pcs cluster enable --all

## Check cluster status
echo "{info} Waiting for cluster to start..."
vm exec -v $node1 -- sleep 8
vm exec -v $node1 -- pcs status

#-------------------------------------------------------------------------------
#Configure fence_scsi
## Get shared device path (assume it's /dev/sda)
RDEV="/dev/sda"

## Create fence_scsi device
vm exec -v $node1 -- pcs stonith create fence-scsi fence_scsi \
    devices=$RDEV \
    pcmk_host_list="$node1 $node2" \
    pcmk_monitor_action=metadata \
    op monitor interval=60s

## Verify fencing configuration
vm exec -v $node1 -- sleep 8
vm exec -v $node1 -- pcs stonith status
vm exec -v $node1 -- pcs status

#-------------------------------------------------------------------------------
#Create LVM and FS on shared disk
vm exec -v $node1 -- pvcreate /dev/sda
vm exec -v $node1 -- vgcreate --setautoactivation n --locktype none nfs_vg /dev/sda
vm exec -v $node1 -- vgchange --locktype none nfs_vg
vm exec -v $node1 -- vgs -o+systemid nfs_vg
vm exec -v $node1 -- vgs -o+lock_type nfs_vg
vm exec -v $node1 -- lvcreate -L 30G -n nfs_lv nfs_vg
vm exec -v $node1 -- mkfs.xfs /dev/nfs_vg/nfs_lv

#-------------------------------------------------------------------------------
#Setup NFS HA
## create resource group
VIP=10.172.192.63
netmasklen=24
netaddr=10.172.192.0/$netmasklen
vm exec -v $node1 -- pcs resource create nfs-lvm ocf:heartbeat:LVM-activate vgname=nfs_vg vg_access_mode=system_id --group nfsgroup
#the directory=/path will be created by `pcs resource create nfs-fs ...`
vm exec -v $node1 -- pcs resource create nfs-fs ocf:heartbeat:Filesystem device=/dev/nfs_vg/nfs_lv directory=/mnt/nfsshare fstype=xfs --group nfsgroup
vm exec -v $node1 -- pcs resource create nfs-vip ocf:heartbeat:IPaddr2 ip=$VIP cidr_netmask=$netmasklen --group nfsgroup
vm exec -v $node1 -- pcs resource create nfs-daemon ocf:heartbeat:nfsserver nfs_shared_infodir=/mnt/nfsshare/nfsinfo --group nfsgroup
vm exec -v $node1 -- 'ls -l /mnt/nfsshare; mkdir -m 755 -p /mnt/nfsshare/exports; ls -l /mnt/nfsshare'
vm exec -v $node2 -- mkdir -p /mnt/nfsshare/exports #only for rhel-8, because the default active node is node2
vm exec -v $node1 -- pcs resource create nfs-export exportfs clientspec="$netaddr" options=rw,sync,no_root_squash directory=/mnt/nfsshare/exports --group nfsgroup

vm exec -v $node1 -- sleep 8
vm exec -v $node1 -- pcs status
vm exec -v $node1 -- pcs resource status nfsgroup

#-------------------------------------------------------------------------------
#client base test
vm exec -v $haclnt -- showmount -e $VIP

#vm exec -v $node1 -- pcs node standby $node1
vm exec -v $node1 -- pcs resource move nfsgroup $node2
vm exec -v $node1 -- sleep 8
vm exec -v $node2 -- pcs status

vm exec -v $haclnt -- showmount -e $VIP
vm exec -v $haclnt -- mkdir -p /mnt/nfsmp
vm exec -v $haclnt -- mount $VIP:/mnt/nfsshare/exports /mnt/nfsmp
vm exec -v $haclnt -- mkdir /mnt/nfsmp/testdir
vm exec -v $haclnt -- touch /mnt/nfsmp/testfile
