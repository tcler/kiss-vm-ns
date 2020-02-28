#!/bin/bash
#ref1: https://tcler.github.io/2018/06/17/pxe-server/
#ref2: http://www.iram.fr/~blanchet/tutorials/diskless-centos-7.pdf
#ref3: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_host_configuration_and_guest_installation_guide/chap-virtualization_host_configuration_and_guest_installation_guide-libvirt_network_booting#chap-Virtualization_Host_Configuration_and_Guest_Installation_Guide-Libvirt_network_booting-PXE_boot_private_network
#ref4: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-disklesssystems

which vm &>/dev/null || {
	echo -e "[WARN] you have not installed kiss-vm, please install kiss-vm first by run:"
	echo -e " git clone https://github.com/tcler/kiss-vm-ns"
	echo -e " sudo make -C kiss-vm-ns"
	echo -e " vm --prepare"
	exit 1
}

argv=()
extrapkgs=()
for arg; do
	case "$arg" in
	-selinux|-selinux=[01]|-selinux=no|-selinux=yes|-selinux=*)
		SELINUX=enforcing
		SEVAL=${arg#-selinux=}
		case "$SEVAL" in 0|no) SELINUX=permissive;; 1|yes) SELINUX=enforcing;; esac
		;;
	-h)   echo "Usage: $0 [distro] [-selinux[={0|1|no|yes}]";;
	-*)   echo "{WARN} unkown option '${arg}'";;
	*)    argv+=($arg);;
	esac
done
set -- "${argv[@]}"

distro=${1:-RHEL-8.1.0}


#---------------------------------------------------------------
sudo -K
while true; do
	read -s -p "sudo Password: " password
	echo
	echo "$password" | sudo -S ls / >/dev/null && break
done

#---------------------------------------------------------------
#install tftp server and configure pxe
echo "$password" | sudo -S yum install -y syslinux tftp-server
# prepare pxelinux.0
echo "$password" | sudo -S mkdir -p /var/lib/tftpboot/pxelinux
echo "$password" | sudo -S cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/pxelinux/.
echo "$password" | sudo -S cp /usr/share/syslinux/ldlinux.c32 /var/lib/tftpboot/pxelinux/. 


#---------------------------------------------------------------
#create virt network pxenet
netaddr=200
vm net netname=pxenet brname=virpxebr0 subnet=$netaddr tftproot=/var/lib/tftpboot bootpfile=pxelinux/pxelinux.0


#---------------------------------------------------------------
#create nfs root
nfsroot=/home/nfsroot
vm $distro -p nfs-utils --net pxenet --nointeract --force
vmname=$(vm --getvmname $distro)

[[ -n "$SELINUX" ]] && extrapkgs+=(selinux-policy selinux-policy-targeted)

cat >prepare-nfsroot.sh <<EOF
#!/bin/bash
mkdir $nfsroot
yum install -y @Base kernel dracut-network nfs-utils ${extrapkgs[@]} --installroot=$nfsroot --releasever=/
cp /etc/resolv.conf ${nfsroot}/etc/resolv.conf
echo "none            /tmp            tmpfs   defaults        0 0" >>${nfsroot}/etc/fstab
echo "tmpfs           /dev/shm        tmpfs   defaults        0 0" >>${nfsroot}/etc/fstab
echo "sysfs           /sys            sysfs   defaults        0 0" >>${nfsroot}/etc/fstab
echo "proc            /proc           proc    defaults        0 0" >>${nfsroot}/etc/fstab

[[ -n "$SELINUX" ]] && sed -i 's/^SELINUX=.*/SELINUX=$SELINUX/' $nfsroot/etc/sysconfig/selinux

ls -lZ /etc/shadow $nfsroot/etc/shadow
chcon --reference=/etc/shadow $nfsroot/etc/shadow
ls -lZ /etc/shadow $nfsroot/etc/shadow
chroot $nfsroot bash -c 'echo redhat | passwd --stdin root'
ls -lZ /etc/shadow $nfsroot/etc/shadow
chcon --reference=/etc/shadow $nfsroot/etc/shadow
ls -lZ /etc/shadow $nfsroot/etc/shadow

echo 'add_dracutmodules+="nfs"' >>$nfsroot/etc/dracut.conf
chroot $nfsroot dracut --no-hostonly --nolvmconf -m "nfs network base" --xz /boot/initramfs.pxe-\$(uname -r) \$(uname -r)
chroot $nfsroot chmod ugo+r /boot/initramfs.pxe-\$(uname -r)
touch $nfsroot/.autorelabel



echo "$nfsroot *(rw,no_root_squash,security_label)" >/etc/exports
systemctl enable nfs-server
systemctl restart nfs-server
EOF

scp -o StrictHostKeyChecking=no prepare-nfsroot.sh root@$vmname:
vm exec $vmname -- bash prepare-nfsroot.sh
vm exec $vmname -- systemctl stop firewalld


#---------------------------------------------------------------
# prepare vmlinuz and initrd.img
while ! vm exec $vmname -- ls $nfsroot/boot; do
	sleep 2
done
bootfiles=$(vm exec $vmname -- ls $nfsroot/boot)
vmlinuz=$(echo "$bootfiles"|grep ^vmlinuz-)
initramfs=$(echo "$bootfiles"|grep ^initramfs.pxe-)
scp -o StrictHostKeyChecking=no root@$vmname:$nfsroot/boot/$vmlinuz .
scp -o StrictHostKeyChecking=no root@$vmname:$nfsroot/boot/$initramfs .
echo "$password" | sudo -S mv $vmlinuz $initramfs /var/lib/tftpboot/pxelinux/.
echo "$password" | sudo -S chcon --reference=/var/lib/tftpboot/pxelinux/pxelinux.0 /var/lib/tftpboot/pxelinux/*


#---------------------------------------------------------------
# generate pxe config file
nfsserv=$(vm ifaddr $vmname | grep "192\\.168\\.$netaddr\\.")
echo "$password" | sudo -S mkdir -p /var/lib/tftpboot/pxelinux/pxelinux.cfg
cat <<EOF | sudo tee /var/lib/tftpboot/pxelinux/pxelinux.cfg/default
# boot rhel-7 with tftp/nfs
default menu.c32
prompt 0

menu title PXE Boot Menu

ontimeout rhel-7
timeout 50

label rhel-7
  menu label Install diskless rhel-7 ${vmlinuz#vmlinuz-}
  kernel $vmlinuz
  append initrd=$initramfs root=nfs4:$nfsserv:$nfsroot:vers=4.2,rw rw panic=60 ipv6.disable=1 console=tty0 console=ttyS0,115200n8

label memtest
  menu label memtest
  kernel memtest86+
EOF
echo "$password" | sudo -S systemctl start tftp

#---------------------------------------------------------------
# install diskless vm
vm ${distro}-pxe --net pxenet --pxe --diskless --force
