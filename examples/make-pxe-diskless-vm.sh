#!/bin/bash
#ref1: https://tcler.github.io/2018/06/17/pxe-server/
#ref2: http://www.iram.fr/~blanchet/tutorials/diskless-centos-7.pdf

#---------------------------------------------------------------
#install tftp server and configure pxe
sudo yum install -y syslinux tftp-server
# prepare pxelinux.0
sudo mkdir -p /var/lib/tftpboot/pxelinux
sudo cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/pxelinux/.
sudo cp /usr/share/syslinux/ldlinux.c32 /var/lib/tftpboot/pxelinux/. 


#---------------------------------------------------------------
#create virt network pxenet
netaddr=200
vm net netname=pxenet brname=virpxebr0 subnet=$netaddr tftproot=/var/lib/tftpboot bootpfile=pxelinux/pxelinux.0


#---------------------------------------------------------------
#create nfs root
nfsroot=/home/nfsroot
vm --prepare
vm RHEL-7.7 -p nfs-utils --net pxenet --nointeract
vmname=$(vm --getvmname RHEL-7.7)
vm exec $vmname -- "echo SELINUX=disabled >>/etc/sysconfig/selinux"
vm reboot /w $vmname

cat >prepare-nfsroot.sh <<EOF
mkdir $nfsroot
yum -y groupinstall Base --installroot=$nfsroot --releasever=/
rm -rf $nfsroot/etc/yum.repos.d
yum -y install kernel nfs-utils --installroot=$nfsroot --releasever=/
cp /etc/resolv.conf ${nfsroot}/etc/resolv.conf
echo "none            /tmp            tmpfs   defaults        0 0 >>${nfsroot}/etc/fstab"
echo "tmpfs           /dev/shm        tmpfs   defaults        0 0 >>${nfsroot}/etc/fstab"
echo "sysfs           /sys            sysfs   defaults        0 0 >>${nfsroot}/etc/fstab"
echo "proc            /proc           proc    defaults        0 0 >>${nfsroot}/etc/fstab"
chroot $nfsroot bash -c 'echo -e "redhat\nredhat" | passwd --stdin root'

echo 'add_dracutmodules+="nfs"' >>$nfsroot/etc/dracut.conf
chroot $nfsroot dracut --no-hostonly --nolvmconf -m "nfs network base" --xz /boot/initramfs.pxe-$(uname -r) $(uname -r)
chroot $nfsroot chmod ugo+r /boot/initramfs.pxe-$(uname -r)

echo "$nfsroot *(rw)" >/etc/exports
systemctl enable nfs-server
systemctl restart nfs-server
EOF

scp -o StrictHostKeyChecking=no prepare-nfsroot.sh root@$vmname:
vm exec $vmname -- bash prepare-nfsroot.sh


#---------------------------------------------------------------
# prepare vmlinuz and initrd.img
bootfiles=$(vm exec $vmname -- ls $nfsroot/boot)
vmlinuz=$(echo "bootfiles"|grep ^vmlinuz-)
initramfs=$(echo "bootfiles"|grep ^initramfs.pxe-)
scp -o StrictHostKeyChecking=no root@$vmname:$nfsroot/boot/$vmlinuz .
scp -o StrictHostKeyChecking=no root@$vmname:$nfsroot/boot/$initramfs .
sudo mv $vmlinuz $initramfs /var/lib/tftpboot/pxelinux/.


#---------------------------------------------------------------
# generate pxe config file
nfsserv=$(vm ifaddr $vmname | grep "192\\.168\\.$netaddr\\.")
sudo mkdir -p /var/lib/tftpboot/pxelinux/pxelinux.cfg
sudo cat <<EOF | tee /var/lib/tftpboot/pxelinux/pxelinux.cfg/default
# boot rhel-7 with tftp/nfs
default menu.c32
prompt 0

menu title PXE Boot Menu

ontimeout rhel-7
timeout 50

label rhel-7
  menu label Install diskless rhel-7 ${vmlinuz#vmlinuz-}
  kernel $vmlinuz
  append initrd=$initramfs root=/dev/nfs nfsroot=$nfsserv:$nfsroot rw panic=60 ipv6.disable=1 console=tty0 console=ttyS0,115200n8

label memtest
  menu label memtest
  kernel memtest86+
EOF
sudo systemctl start tftp

#---------------------------------------------------------------
# install diskless vm
vm RHEL-7.7-pxe --net pxenet --pxe --diskless
