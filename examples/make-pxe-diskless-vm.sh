#!/bin/bash
#ref1: https://tcler.github.io/2018/06/17/pxe-server/
#ref2: http://www.iram.fr/~blanchet/tutorials/diskless-centos-7.pdf
#ref3: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_host_configuration_and_guest_installation_guide/chap-virtualization_host_configuration_and_guest_installation_guide-libvirt_network_booting#chap-Virtualization_Host_Configuration_and_Guest_Installation_Guide-Libvirt_network_booting-PXE_boot_private_network
#ref4: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-disklesssystems

command -v vm >/dev/null || {
	echo -e "[WARN] you have not installed kiss-vm, please install kiss-vm first by run:"
	echo -e " git clone https://github.com/tcler/kiss-vm-ns"
	echo -e " sudo make -C kiss-vm-ns"
	echo -e " vm prepare"
	exit 1
}

argv=()
extrapkgs=()
Usage() { echo "Usage: $0 [distro] [-selinux[={0|1|no|yes}]"; }
for arg; do
	case "$arg" in
	-selinux|-selinux=[01]|-selinux=no|-selinux=yes|-selinux=*)
		SELINUX=enforcing
		SEVAL=${arg#-selinux=}
		case "$SEVAL" in 0|no) SELINUX=permissive;; 1|yes) SELINUX=enforcing;; esac
		;;
	-h|--h*)
		Usage; exit;;
	-*)   echo "{WARN} unkown option '${arg}'";;
	*)    argv+=($arg);;
	esac
done
set -- "${argv[@]}"

distro=${1:-RHEL-8.5.0}
echo -e "\n================ [DEBUG] ===============\n= distro/family: $distro"

#---------------------------------------------------------------
[[ $(id -u) != 0 ]] && {
	sudo -K
	while true; do
		read -s -p "sudo Password: " password
		echo
		echo "$password" | sudo -S ls / >/dev/null && break
	done
}

#---------------------------------------------------------------
#install tftp server and configure pxe
echo -e "\n================ [INFO] ================\n= prepare tftp-server /var/lib/tftpboot/pxelinux:"
echo "$password" | sudo -S yum install -y syslinux tftp-server
# prepare pxelinux.0
echo "$password" | sudo -S mkdir -p /var/lib/tftpboot/pxelinux
echo "$password" | sudo -S cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/pxelinux/.
echo "$password" | sudo -S cp /usr/share/syslinux/ldlinux.c32 /var/lib/tftpboot/pxelinux/. 


#---------------------------------------------------------------
#create virt network pxenet
echo -e "\n[INFO] create pxe virt network"
netname=pxenet
brname=virpxebr0
netaddr=200
vm netcreate netname=$netname brname=$brname subnet=$netaddr tftproot=/var/lib/tftpboot bootpfile=pxelinux/pxelinux.0
vm netinfo $netname
vm netls

#---------------------------------------------------------------
#create nfs root
nfsroot=/nfsroot
vmname=pxe-nfs-server
echo -e "\n================ [INFO] ================\n= create nfs server of sysroot for diskless guest"
vm $distro -n $vmname --msize=4G --dsize=80 -p "nfs-utils deltarpm" --net pxenet --nointeract --force
vm exec $vmname ls || exit $?

[[ -n "$SELINUX" ]] && extrapkgs+=(selinux-policy selinux-policy-targeted)

dlvmname=linux-diskless
cat >prepare-nfsroot.sh <<EOF
#!/bin/bash
mkdir $nfsroot
yum install --setopt=strict=0 -y @Base @Minimal\ Install kernel dracut-network openssh openssh-server nfs-utils ${extrapkgs[@]} --installroot=$nfsroot --releasever=/
cp /etc/resolv.conf ${nfsroot}/etc/resolv.conf
echo "none            /tmp            tmpfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "devtmpfs        /dev            devtmpfs defaults        0 0" >>${nfsroot}/etc/fstab
echo "tmpfs           /dev/shm        tmpfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "sysfs           /sys            sysfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "proc            /proc           proc     defaults        0 0" >>${nfsroot}/etc/fstab

[[ -n "$SELINUX" ]] && sed -i 's/^SELINUX=.*/SELINUX=$SELINUX/' $nfsroot/etc/sysconfig/selinux

ls -lZ /etc/shadow $nfsroot/etc/shadow
chcon --reference=/etc/shadow $nfsroot/etc/shadow
ls -lZ /etc/shadow $nfsroot/etc/shadow
chroot $nfsroot bash -c 'echo redhat | passwd --stdin root'
ls -lZ /etc/shadow $nfsroot/etc/shadow
chcon --reference=/etc/shadow $nfsroot/etc/shadow
ls -lZ /etc/shadow $nfsroot/etc/shadow

#https://superuser.com/questions/165116/mount-dev-proc-sys-in-a-chroot-environment
#https://stackallflow.com/unix-linux/recursive-umount-after-rbind-mount/
mount -t proc /proc $nfsroot/proc; mount --rbind /sys $nfsroot/sys; mount --make-rslave $nfsroot/sys; mount --rbind /dev $nfsroot/dev; mount --make-rslave $nfsroot/dev
  echo 'add_dracutmodules+=" nfs "' >>$nfsroot/etc/dracut.conf
  VR=\$(chroot /nfsroot/ bash -c 'ls /boot/config-*|sed s/.*config-//')
  chroot $nfsroot dracut --no-hostonly --nolvmconf \\
	-m "nfs network base qemu " --xz /boot/initramfs.pxe-\$VR \$VR
	#--add-drivers "virtio_net virtio_scsi virtio_pci virtio_ring virtio" \\
  chroot $nfsroot chmod ugo+r /boot/initramfs.pxe-\$(uname -r)
umount $nfsroot/proc; umount -R $nfsroot/dev; umount -R $nfsroot/sys;
touch $nfsroot/.autorelabel


echo "$nfsroot *(rw,no_root_squash,security_label)" >/etc/exports
systemctl enable nfs-server
systemctl restart nfs-server

cp /etc/yum.repos.d/*.repo ${nfsroot}/etc/yum.repos.d/.

echo "$dlvmname" >${nfsroot}/etc/hostname
authKeys="$(for F in ~/.ssh/id_*.pub; do tail -n1 $F; done)"
#mkdir -p ${nfsroot}/root/.ssh && echo "\$authKeys" >>${nfsroot}/root/.ssh/authorized_keys
mkdir -p ${nfsroot}/root/.ssh && cp /root/.ssh/authorized_keys ${nfsroot}/root/.ssh/authorized_keys
EOF

vm cpto $vmname prepare-nfsroot.sh . && rm -f prepare-nfsroot.sh
vm exec $vmname -- bash prepare-nfsroot.sh
vm exec $vmname -- systemctl stop firewalld


#---------------------------------------------------------------
# prepare vmlinuz and initrd.img
echo -e "\n================ [INFO] ================\n= prepare vmlinuz and initrd.img for pxelinux boot"
while ! vm exec $vmname -- ls $nfsroot/boot; do
	sleep 2
done
distrofamily=$(vm exec $vmname -- awk -F'[="]+' '/^(ID|VERSION_ID)=/{printf($2)}' /etc/os-release)
bootfiles=$(vm exec $vmname -- ls $nfsroot/boot)
vmlinuz=$(echo "$bootfiles"|grep ^vmlinuz-|sort -V|tail -1)
initramfs=$(echo "$bootfiles"|grep ^initramfs.pxe-)
tmpdir=$(mktemp -d)
vm cpfrom $vmname $nfsroot/boot/$vmlinuz $tmpdir/.
vm cpfrom $vmname $nfsroot/boot/$initramfs $tmpdir/.
echo "$password" | sudo -S mv $tmpdir/* /var/lib/tftpboot/pxelinux/.
echo "$password" | sudo -S chmod a+r $initramfs /var/lib/tftpboot/pxelinux/*
echo "$password" | sudo -S chcon --reference=/var/lib/tftpboot/pxelinux/pxelinux.0 /var/lib/tftpboot/pxelinux/*
rm -fr $tmpdir


#---------------------------------------------------------------
# generate pxe config file
echo -e "\n================ [INFO] ================\n= generate pxe config file ..."
nfsserv=$(vm ifaddr $vmname | grep "192\\.168\\.$netaddr\\.")
echo "$password" | sudo -S mkdir -p /var/lib/tftpboot/pxelinux/pxelinux.cfg
cat <<EOF | sudo tee /var/lib/tftpboot/pxelinux/pxelinux.cfg/default
# boot ${distrofamily} with tftp/nfs
default menu.c32
prompt 0

menu title PXE Boot Menu

ontimeout ${distrofamily}
timeout 50

label ${distrofamily}
  menu label Install diskless ${distrofamily} ${vmlinuz#vmlinuz-}
  kernel $vmlinuz
  append initrd=$initramfs root=nfs4:$nfsserv:$nfsroot:vers=4.2,rw rw panic=60 ipv6.disable=1 console=tty0 console=ttyS0,115200n8

label memtest
  menu label memtest
  kernel memtest86+
EOF
echo "$password" | sudo -S systemctl start tftp

#---------------------------------------------------------------
# install diskless vm
echo -e "\n================ [INFO] ================\n= create diskless guest over nfs ..."
vm create ${distro}-pxe -n $dlvmname --net pxenet --net default --pxe --diskless --force
