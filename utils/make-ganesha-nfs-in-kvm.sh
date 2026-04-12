#!/bin/bash
# author: Jianhong Yin <yin-jianhong@163.com>
# build a 4-node ganesha-nfs pNFS server cluster in libvirt/KVM
#
# REF:
# - https://github.com/nfs-ganesha/nfs-ganesha/wiki
# - https://docs.gluster.org/en/latest/Administrator-Guide/NFS-Ganesha-and-GlusterFS/
# - deepseek
#
# Verified: [RHEL-10, Fedora-44]

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }
export LANG=C

P=${0##*/}
Usage() {
	cat <<-EOF
	Usage:
	  $P [--ganesha=<[5-9]>] <distro-(name|pattern)> [-- vm-create-options]

	Options:
	  -h, -help         ; show this help
	  --ganesha=        ; give a centos sig ganesha-version, default is 7
	EOF
}

_at=$(getopt -a -o h \
	--long help \
	--long ganesha: \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	--ganesha) ganeshaver=${2}; shift 2;;
	--) shift; break;;
	esac
done
[[ $# = 0 ]] && { Usage >&2; exit 1; }
distro=$1; shift

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

#-------------------------------------------------------------------------------
#create VMs for Ganesha-NFS pNFS cluster
# Architecture: 1 MDS + 3 DS
mds=ganesha-mds
ds1=ganesha-ds01
ds2=ganesha-ds02
ds3=ganesha-ds03
ganeshaclnt=ganesha-client

# Common packages for all Ganesha servers
pkgs=vim,tmux,nfs-ganesha,nfs-ganesha-vfs

# Client packages
clntpkgs=vim,tmux,nfs-utils

echo "{info} Creating Ganesha-NFS pNFS cluster VMs..."
# Create MDS node
trun -tmux=$mds-$$ vm create -f -n $mds $distro --nointeract -p $pkgs --net=kissaltnet "$@"

# Create DS nodes
trun -tmux=$ds1-$$ vm create -f -n $ds1 $distro --nointeract -p $pkgs --net=kissaltnet "$@"
trun -tmux=$ds2-$$ vm create -f -n $ds2 $distro --nointeract -p $pkgs --net=kissaltnet "$@"
trun -tmux=$ds3-$$ vm create -f -n $ds3 $distro --nointeract -p $pkgs --net=kissaltnet "$@"

# Create client node
trun               vm create -f -n $ganeshaclnt $distro --nointeract -p $clntpkgs --net=kissaltnet "$@"

# Wait for all VM creations to complete
while tmux ls | grep -E "($mds|$ds1|$ds2|$ds3|$ganeshaclnt)"-$$; do sleep 5; done

#-------------------------------------------------------------------------------
# Stop firewalld on all nodes (simplify setup)
for vmn in $mds $ds1 $ds2 $ds3; do 
	vm exec -v  $vmn -- 'systemctl disable firewalld --now 2>/dev/null'
	vm exec -v  $vmn -- "sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config; setenforce 0"
	vm cpto -v  $vmn /usr/bin/enable-centos-sig-repos.sh /bin
	vm exec -vx $vmn -- enable-centos-sig-repos.sh ganesha=${ganeshaver:-7}
	vm exec -vx $vmn -- yum install -y ${pkgs//,/ } --nobest
	vm exec -vx $vmn -- rpm -q nfs-ganesha || exit 1
done

#-------------------------------------------------------------------------------
# Setup hostname resolution
read mdsIp _ < <(vm ifaddr $mds)
read ds1Ip _ < <(vm ifaddr $ds1)
read ds2Ip _ < <(vm ifaddr $ds2)
read ds3Ip _ < <(vm ifaddr $ds3)

for node in $mds $ds1 $ds2 $ds3; do
	vm exec -v $node -- "echo '$mdsIp $mds' >>/etc/hosts"
	vm exec -v $node -- "echo '$ds1Ip $ds1' >>/etc/hosts"
	vm exec -v $node -- "echo '$ds2Ip $ds2' >>/etc/hosts"
	vm exec -v $node -- "echo '$ds3Ip $ds3' >>/etc/hosts"
done

#-------------------------------------------------------------------------------
# Prepare shared storage
# For pNFS, all nodes need access to the same backing storage
# Here we create a shared directory structure on each node (for demo)
# In production, this would be a shared filesystem like GlusterFS or Ceph
for node in $ds1 $ds2 $ds3 $mds; do
	vm exec -v $node -- 'mkdir -p /export/shared'
	vm exec -v $node -- 'mkdir -p /var/lib/nfs/ganesha'
	vm exec -v $node -- 'chmod 755 /export/shared'
done

#-------------------------------------------------------------------------------
# Configure Ganesha-NFS - DS Nodes
echo '{info} Configuring Ganesha-NFS on DS nodes...'
for dsnode in $ds1 $ds2 $ds3; do
	vm exec -v $dsnode -- 'cat > /etc/ganesha/ganesha.conf << "EOF"
NFS_CORE_PARAM {
    Protocols = 4.1;
    NFS_Port = 2049;
    NFS_Threads = 32;
}

EXPORT_DEFAULTS {
    Attr_Expiration_Time = 3600;
    FSAL {
        Name = VFS;
    }
}

EXPORT {
    Export_Id = 1;
    Path = "/export/shared";
    Access_Type = RW;
    Squash = No_Root_Squash;
    SecType = "sys";
    Transports = "TCP";
    Protocols = 4;

    # Data Server configuration
    PNFS_DS = true;
    FSAL {
        Name = VFS;
    }
}

LOG {
    Default_Log_Level = INFO;
}
EOF'
done

#-------------------------------------------------------------------------------
# Configure Ganesha-NFS - MDS Node
echo '{info} Configuring Ganesha-NFS on MDS node...'
vm exec -v $mds -- 'cat > /etc/ganesha/ganesha.conf << "EOF"
NFS_CORE_PARAM {
    Protocols = 4.1;
    NFS_Port = 2049;
    NFS_Threads = 32;
}

EXPORT_DEFAULTS {
    Attr_Expiration_Time = 3600;
    Close_Timeout = 90;
    FSAL {
        Name = VFS;
    }
}

EXPORT {
    Export_Id = 1;
    Path = "/export/shared";
    Pseudo = "/pnfs_export";
    Access_Type = RW;
    Squash = No_Root_Squash;
    SecType = "sys";
    Transports = "TCP";
    Protocols = 4;

    # pNFS configuration
    PNFS_DS = true;
    FSAL {
        Name = VFS;
        # DS nodes list
        DS_Hosts = '"$ds1"', '"$ds2"', '"$ds3"';
    }
}

LOG {
    Default_Log_Level = INFO;
    #Facility = LOG_LOCAL5;
}
EOF'

#-------------------------------------------------------------------------------
# Start and enable NFS-Ganesha on all nodes
echo '{info} Starting Ganesha-NFS services...'

for node in $ds1 $ds2 $ds3 $mds; do
	vm exec -v $node -- 'systemctl enable rpcbind --now'
	vm exec -v $node -- 'systemctl enable nfs-ganesha --now'
done

# Check service status
for node in $mds $ds1 $ds2 $ds3; do
	vm exec -v $node -- 'systemctl status nfs-ganesha --no-pager | head -10'
done

#-------------------------------------------------------------------------------
# Verify exports on MDS
echo '{info} Verifying NFS exports on MDS...'
vm exec -v  $mds -- 'showmount -e localhost'
vm exec -v  $mds -- 'journalctl -u nfs-ganesha --no-pager | tail -20'
vm exec -vx $mds -- 'rpcinfo -p localhost | grep 100003' || exit 1
