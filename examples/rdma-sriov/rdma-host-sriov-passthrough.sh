#RDMA Mellanox ConnectX-3 card SR-IOV configure:
#ref: https://community.mellanox.com/s/article/howto-configure-sr-iov-for-connectx-3-with-kvm--infiniband-x  #configure sr-iov
#ref: https://community.mellanox.com/s/article/howto-install-mlnx-ofed-driver  #install ofed driver
#ref: https://cn.mellanox.com/products/infiniband-drivers/linux/mlnx_ofed  #ofed driver download page

LANG=C

# add kernel option "intel_iommu=on iommu=pt" and reboot
: <<\COMM
yum install -y grubby
grubby --args="intel_iommu=on iommu=pt" --update-kernel="$(/sbin/grubby --default-kernel)"
reboot
COMM

# download MLNX_OFED driver
wget http://fs-qe.usersys.redhat.com/ftp/pub/jiyin/MLNX_OFED_LINUX-4.9-4.0.8.0-rhel8.4-x86_64.tgz

# install MLNX_OFED driver
tar zxf MLNX_OFED_LINUX-4.9-4.0.8.0-rhel8.4-x86_64.tgz
pushd MLNX_OFED_LINUX-4.9-4.0.8.0-rhel8.4-x86_64
	# install dependency
	yum install -y tcsh tcl tk python36 gcc-gfortran lsof

	#:if OSVER = 8.4
	  ./mlnxofedinstall --enable-nfsordma --force
	  lspci | grep Mellanox
	#:else #always get fail, don't try
	  #yum install -y createrepo rpm-build gdb-headless python36-devel kernel-devel kernel-rpm-macros elfutils-libelf-devel pciutils
	  #./mlnxofedinstall --enable-nfsordma --skip-distro-check --add-kernel-support --force
	#:fi

	# restart openibd
	systemctl stop opensm
	/etc/init.d/opensmd stop
	modprobe -r rpcrdma ib_srpt ib_isert
	/etc/init.d/openibd restart

	lspci | grep Mellanox
	/etc/init.d/opensmd restart
popd

# only once: update firmware enable SRIOV_EN and set NUM_OF_VFS
: <<\COMM
mst start
mst status

mdevs=$(mst status | awk  '/^.dev.mst.*pciconf0/{print $1}')
mdevs=$(for mdev in $mdevs; do
	mlxconfig -d $mdev q |& awk '/Device:/{print $2}'
done)
for mdev in $mdevs; do
	mlxconfig -d $mdev set SRIOV_EN=1 NUM_OF_VFS=16
done

# reboot to take effect
reboot
COMM

# module configure, and reload
systemctl stop opensm
/etc/init.d/opensmd stop
modprobe -r rpcrdma ib_srpt ib_isert
echo "options mlx4_core port_type_array=1,1 num_vfs=16 probe_vf=8" >/etc/modprobe.d/mlx4_core.conf
/etc/init.d/openibd restart
lspci | grep Mellanox
systemctl start opensm #need confirm
ip -br -c a s

# install kiss-vm tool
install-kiss-vm-ns() {
	local _name=$1
	local KissUrl=https://github.com/tcler/kiss-vm-ns
	which vm &>/dev/null || {
		echo -e "{info} installing kiss-vm-ns ..."
		which git &>/dev/null || yum install -y git
		while true; do
			git clone --depth=1 "$KissUrl" && make -C kiss-vm-ns
			which vm && break
			sleep 5
			echo -e "{warn} installing kiss-vm-ns  fail, try again ..."
		done
	}
	[[ "$_name"x = "vm"x ]] && vm prepare
}
install-kiss-vm-ns vm

# create RHEL-8.4 vm
vm create RHEL-8.4.0 -n rhel-8-rdma --nointeract \
	-p "kernel-modules-extra rdma opensm infiniband-diags librdmacm-utils" \
	--hostif=ib4
#method to attach host dev to Guest VM, if no --hostdev,--hostif option
: <<\COMM
cat >pci_0000_04_00_1.xml <<EOF
<hostdev mode='subsystem' type='pci' managed='no'>
<driver name='vfio'/>
<source>
    <address domain='0x0000' bus='0x04' slot='0x00' function='0x1'/>
</source>
</hostdev>
EOF
virsh nodedev-detach pci_0000_04_00_1
virsh attach-device rhel-8-rdma pci_0000_04_00_1.xml
COMM

# create windows server vm
vm create Windows-server-2019 -n win2019-rdma \
	-C $LOOKASIDE_BASE_URL/windows-images/Win2019-Evaluation.iso \
	--osv win2k19 \
	--vcpus sockets=1,cores=4 --msize 8192 --dsize 80 \
	--hostif=ib6 \
	--win-domain win-rdma.test --win-passwd ~Ocgxyz \
	--win-enable-kdc \
	--win-download-url=http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe \
	--win-run='./MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe /S /V\"/qb /norestart\"' \
	--win-run-post='ipconfig /all; ibstat' \
	--win-auto=cifs-nfs --force --wait=22
vm cpfrom win2019-rdma /postinstall_logs/ipconfig.log /tmp/win2019-rdma.ipconfig.log
dos2unix /tmp/win2019-rdma.ipconfig.log

WIN_RDMA_IP=$(awk -v RS='\r?\n' '$NF ~ /^169.254/ {print $NF}' /tmp/win2019-rdma.ipconfig.log)
# download windows driver
# ref: https://www.mellanox.com/products/adapter-software/ethernet/windows/winof-2
# ref: http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe
# ref: http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_53000_All_Win2016_x64.exe
# ref: http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_53000_All_Win2012R2_x64.exe


# guest:
vm exec rhel-serv -- sed -i -e '/rdma/s/^#//' -e 's/rdma=n/rdma=y/' /etc/nfs.conf
vm exec rhel-serv -- systemctl start nfs-server
vm exec rhel-serv -- modprobe mlx4_ib
vm exec rhel-serv -- systemctl start opensm
vm exec rhel-serv -- lspci
vm exec rhel-serv -- ibstat
ibn=$(vm exec rhel-serv -- ip -br a | awk '/^ib.*UP/{print $1}' | tail -n1)
vm exec rhel-serv -- ip link set dev $ibn up
vm exec rhel-serv -- ip addr add 169.254.1.100/16 dev $ibn
vm exec rhel-serv -- ping -c 4 169.254.100.100
vm exec rhel-serv -- ping -c 4 $WIN_RDMA_IP
vm exec rhel-serv -- showmount -e $WIN_RDMA_IP

# host:
ibif=$(ip -br a | awk '/^ib.*UP/ {print $1}' | tail -n1)
ip addr add 169.254.1.1/16 dev $ibif
ping -c 4 $WIN_RDMA_IP
showmount -e $WIN_RDMA_IP

