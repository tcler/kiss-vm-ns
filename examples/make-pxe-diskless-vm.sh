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

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

argv=()
extrapkgs=()
dracutSelinux=
Usage() { echo "Usage: $0 [distro] [-selinux[={0|1|permissive|enforcing}[,{target*|min*|mls}]]"; }
for arg; do
	case "$arg" in
	-selinux|-selinux=*)
		read _ SELINUX SELINUXTYPE <<<${arg//[=,]/ }
		SELINUX=${SELINUX:-permissive}
		SELINUXTYPE=${SELINUXTYPE:-targeted}
		case "$SELINUX" in 0|pe*) SELINUX=permissive;; 1|en*) SELINUX=enforcing;; esac
		case "$SELINUXTYPE" in tar*) SELINUXTYPE=targeted;; mi*) SELINUXTYPE=minimum;; ml*) SELINUXTYPE=mls;; esac
		;;
	-h|--h*)
		Usage; exit;;
	#-*)   echo "{WARN} unkown option '${arg}'";;
	*)    argv+=("$arg");;
	esac
done
set -- "${argv[@]}"

distro=${1:-CentOS-8-stream}; shift
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
echo "$password" | sudo -S cp /usr/share/syslinux/{pxelinux.0,ldlinux.c32,libutil.c32,libcom32.c32,*menu.c32} /var/lib/tftpboot/pxelinux/.


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
vm create $distro -n $vmname --msize=4G --dsize=80 -p "nfs-utils deltarpm" --net pxenet --nointeract --force "$@"
vm exec $vmname ls || exit $?
vm exec $vmname ls --help| grep -q time:.birth &&
	lsOpt='--time=birth'

[[ -n "$SELINUX" ]] && {
	echo -e "\n================ [INFO] ================\n= prepare tftp-server /var/lib/tftpboot/pxelinux:"
	extrapkgs+=(selinux-policy selinux-policy-$SELINUXTYPE)
	dracutSelinux= #selinux
}

distrofamily=$(vm exec $vmname -- awk -F'[="]+' '/^(ID|VERSION_ID)=/{printf($2)}' /etc/os-release)
dlhostname=linux-diskless-$distrofamily
cat >prepare-nfsroot.sh <<EOF
#!/bin/bash
mkdir $nfsroot
BaseGroup=@Base
groupList=\$(yum grouplist hidden|sed 's/^ *//')
if ! grep -q '^Base$' <<<"\$groupList"; then
	BaseGroup="@Server @core @Standard"
fi
yum install --setopt=strict=0 -y \$BaseGroup kernel dracut-network rootfiles passwd openssh openssh-server nfs-utils ${extrapkgs[@]} --installroot=$nfsroot --releasever=/
cp --remove-destination /*.rpm ${nfsroot}/tmp/.
chroot $nfsroot bash -c 'rpm -Uvh /tmp/*.rpm --force --nodeps'
cp --remove-destination /etc/resolv.conf ${nfsroot}/etc/resolv.conf
echo "none            /tmp            tmpfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "devtmpfs        /dev            devtmpfs defaults        0 0" >>${nfsroot}/etc/fstab
echo "tmpfs           /dev/shm        tmpfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "sysfs           /sys            sysfs    defaults        0 0" >>${nfsroot}/etc/fstab
echo "proc            /proc           proc     defaults        0 0" >>${nfsroot}/etc/fstab

echo "$dlhostname" >${nfsroot}/etc/hostname

[[ -n "$SELINUX" ]] && {
	sed -i -e 's/^SELINUX=.*/SELINUX=$SELINUX/' -e 's/^SELINUXTYPE=.*/SELINUXTYPE=$SELINUXTYPE/' \\
		$nfsroot/etc/sysconfig/selinux $nfsroot/etc/selinux/config
}

chcon --reference=/etc/shadow $nfsroot/etc/shadow*
chcon --reference=/etc/passwd $nfsroot/etc/passwd*
chroot $nfsroot bash -c 'echo redhat | passwd --stdin root'
chcon --reference=/etc/shadow $nfsroot/etc/shadow*
chcon --reference=/etc/passwd $nfsroot/etc/passwd*
[[ -f /etc/rc.d/rc.local ]] && {
	echo 'command -v iptables && { iptables -P INPUT ACCEPT;
		iptables -P OUTPUT ACCEPT;
		iptables -P FORWARD ACCEPT;
		iptables -F; }' >>$nfsroot/etc/rc.d/rc.local
	chmod +x $nfsroot/etc/rc.d/rc.local
}

#https://superuser.com/questions/165116/mount-dev-proc-sys-in-a-chroot-environment
#https://stackallflow.com/unix-linux/recursive-umount-after-rbind-mount/
mount -t proc /proc $nfsroot/proc; mount --rbind /sys $nfsroot/sys; mount --make-rslave $nfsroot/sys; mount --rbind /dev $nfsroot/dev; mount --make-rslave $nfsroot/dev
  echo 'add_dracutmodules+=" nfs "' >>$nfsroot/etc/dracut.conf
  VR=\$(chroot /nfsroot/ bash -c 'ls /boot/config-* -t1 ${lsOpt:--u}|head -1|sed s/.*config-//')
  extraDracutModules="dracut-systemd"
  chroot $nfsroot dracut --no-hostonly --nolvmconf \\
	-m "nfs network base qemu $dracutSelinux \$extraDracutModules" --xz /boot/initramfs.pxe-\$VR \$VR \\
	--add-drivers="qxl" --omit-drivers="ahci" || {
	echo -e "\n{dracut} remove \$extraDracutModules, and retry:"
	chroot $nfsroot dracut --no-hostonly --nolvmconf \\
		-m "nfs network base qemu $dracutSelinux" --xz /boot/initramfs.pxe-\$VR \$VR \\
		--add-drivers="qxl" --omit-drivers="ahci"
  }
  chroot $nfsroot chmod ugo+r /boot/initramfs.pxe-\$VR
umount $nfsroot/proc; umount -R $nfsroot/dev; umount -R $nfsroot/sys;
touch $nfsroot/.autorelabel


echo "$nfsroot *(fsid=0,rw,sync,no_root_squash,security_label)" >/etc/exports
echo "$nfsroot/etc *(rw,no_root_squash,security_label)" >>/etc/exports
echo "$nfsroot/usr *(rw,no_root_squash,security_label)" >>/etc/exports
echo "$nfsroot/usr/lib *(rw,no_root_squash,security_label)" >>/etc/exports
echo "$nfsroot/usr/lib/systemd *(rw,no_root_squash,security_label)" >>/etc/exports
echo "$nfsroot/usr/bin *(rw,no_root_squash,security_label)" >>/etc/exports
echo "$nfsroot/usr/sbin *(rw,no_root_squash,security_label)" >>/etc/exports
systemctl enable nfs-server
systemctl restart nfs-server

cp /etc/yum.repos.d/*.repo ${nfsroot}/etc/yum.repos.d/.

#authKeys=$(printf %q "$(for F in ~/.ssh/id_*.pub; do tail -n1 $F; done)")
#mkdir -p ${nfsroot}/root/.ssh && echo "\$authKeys" >>${nfsroot}/root/.ssh/authorized_keys
mkdir -p ${nfsroot}/root/.ssh && cp /root/.ssh/authorized_keys ${nfsroot}/root/.ssh/authorized_keys
EOF

vm cpto $vmname prepare-nfsroot.sh . && rm -f prepare-nfsroot.sh
vm exec $vmname -- bash prepare-nfsroot.sh
vm exec $vmname -- systemctl stop firewalld


#---------------------------------------------------------------
# prepare vmlinuz and initrd.img
echo -e "\n================ [INFO] ================\n= prepare vmlinuz and initrd.img for pxelinux boot"
vm exec $vmname -- ls -l $nfsroot/boot
bootfiles=$(vm exec $vmname -- ls $nfsroot/boot -t1 ${lsOpt:--u})
vmlinuz=$(echo "$bootfiles"|grep ^vmlinuz-|head -1)
initramfs=$(echo "$bootfiles"|grep ^initramfs.pxe-)
tmpdir=$(mktemp -d)
vm cpfrom $vmname $nfsroot/boot/$vmlinuz $tmpdir/.
vm cpfrom $vmname $nfsroot/boot/$initramfs $tmpdir/.
echo "$password" | sudo -S mv $tmpdir/* /var/lib/tftpboot/pxelinux/.
echo "$password" | sudo -S chmod a+r /var/lib/tftpboot/pxelinux/*
echo "$password" | sudo -S chcon --reference=/var/lib/tftpboot/pxelinux/pxelinux.0 /var/lib/tftpboot/pxelinux/*
echo "$password" | sudo -S rm -fr $tmpdir

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

ontimeout ${distrofamily}-over-nfsv4.2
timeout 120

label ${distrofamily}-over-nfsv4.2
  menu label Install diskless nfsv4.2 ${distrofamily} ${vmlinuz#vmlinuz-}
  kernel $vmlinuz
  append initrd=$initramfs root=nfs4:$nfsserv:/:vers=4.2,rw rw panic=60 ipv6.disable=1 console=tty0 console=ttyS0,115200n8

label ${distrofamily}-over-nfsv3
  menu label Install diskless nfsv3 ${distrofamily} ${vmlinuz#vmlinuz-}
  kernel $vmlinuz
  append initrd=$initramfs root=nfs:$nfsserv:$nfsroot:vers=3,rw rw panic=60 ipv6.disable=1 console=tty0 console=ttyS0,115200n8

label memtest
  menu label memtest
  kernel memtest86+
EOF
echo "$password" | sudo -S systemctl start tftp

#---------------------------------------------------------------
# install diskless vm
dlvmname=linux-diskless
echo -e "\n================ [INFO] ================\n= create diskless guest over nfs ..."
vm create ${distro}-pxe -n ${dlvmname}-nfsv4 --net pxenet --net default --pxe --diskless --force --vncwait="less.nfsv3,key:enter" --vncwait="less.nfsv3,key:enter"
#vm create ${distro}-pxe -n ${dlvmname}-nfsv3 --net pxenet --net default --pxe --diskless --force --vncwait="less.nfsv3,key:down key:enter" --vncwait="less.nfsv3,key:down key:enter"
