declare -A distroInfo

#### CentOS stream and CentOS
_GuestARCH=$GuestARCH; [[ "$GuestARCH" = ppc64 ]] && _GuestARCH=ppc64le;
distroInfo[Rocky-9]="https://mirrors.sdu.edu.cn/rocky/9/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/9/BaseOS/$_GuestARCH/os"
distroInfo[Rocky-8]="https://mirrors.sdu.edu.cn/rocky/8/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/8/BaseOS/$_GuestARCH/os"
distroInfo[CentOS-9-stream]="https://cloud.centos.org/centos/9-stream/$_GuestARCH/images/ http://mirror.stream.centos.org/9-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8-stream]="https://cloud.centos.org/centos/8-stream/$_GuestARCH/images/ http://mirror.centos.org/centos/8-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8]="https://cloud.centos.org/centos/8/$_GuestARCH/images/ http://mirror.centos.org/centos/8/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-7]="https://cloud.centos.org/centos/7/images/%%GenericCloud-.{4}.qcow2c http://mirror.centos.org/centos/7/os/$_GuestARCH/"
distroInfo[CentOS-6]="https://cloud.centos.org/centos/6/images/%%GenericCloud.qcow2c http://mirror.centos.org/centos/6/os/$_GuestARCH/"

#### Fedora
# https://ord.mirror.rackspace.com/fedora/releases/$version/Cloud/
distroInfo[fedora-rawhide]="https://ord.mirror.rackspace.com/fedora/development/rawhide/Cloud/$GuestARCH/images/"
distroInfo[fedora-37]="https://ord.mirror.rackspace.com/fedora/releases/37/Cloud/$GuestARCH/images/"
distroInfo[fedora-36]="https://ord.mirror.rackspace.com/fedora/releases/36/Cloud/$GuestARCH/images/"
distroInfo[fedora-35]="https://ord.mirror.rackspace.com/fedora/releases/35/Cloud/$GuestARCH/images/"
distroInfo[fedora-34]="https://ord.mirror.rackspace.com/fedora/releases/34/Cloud/$GuestARCH/images/"
distroInfo[fedora-33]="https://ord.mirror.rackspace.com/fedora/releases/33/Cloud/$GuestARCH/images/"
distroInfo[fedora-32]="https://ord.mirror.rackspace.com/fedora/releases/32/Cloud/$GuestARCH/images/"
distroInfo[fedora-31]="https://ord.mirror.rackspace.com/fedora/releases/31/Cloud/$GuestARCH/images/"

#### Debian
# https://cloud.debian.org/images/openstack/testing/
# https://cloud.debian.org/images/openstack/$latestVersion/
# https://cloud.debian.org/images/openstack/archive/$olderVersion/
distroInfo[debian-12]="http://cloud.debian.org/images/cloud/bookworm/latest/"
distroInfo[debian-11]="http://cloud.debian.org/images/cloud/bullseye/latest/"
distroInfo[debian-10]="https://cloud.debian.org/images/openstack/current-10/debian-10-openstack-${GuestARCH/x86_64/amd64}.qcow2"
distroInfo[debian-9]="https://cloud.debian.org/images/openstack/current-9/debian-9-openstack-${GuestARCH/x86_64/amd64}.qcow2"
distroInfo[debian-testing]="https://cloud.debian.org/images/openstack/testing/"

#### OpenSUSE
distroInfo[openSUSE-leap-15.5]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.4]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.3]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.3/images/openSUSE-Leap-15.3.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.2]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.2/images/openSUSE-Leap-15.2-OpenStack.$GuestARCH.qcow2"

#### FreeBSD
distroInfo[FreeBSD-12.4]="https://download.freebsd.org/ftp/releases/VM-IMAGES/12.4-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-13.2]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.2-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-13.1]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.1-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-14.0]="https://download.freebsd.org/ftp/snapshots/VM-IMAGES/14.0-CURRENT/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"

#### ArchLinux
distroInfo[archlinux]="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-${GuestARCH}-cloudimg.qcow2"
distroInfo[archlinux]="https://linuximages.de/openstack/arch/arch-openstack-LATEST-image-bootstrap${GuestARCH/x86_64/}.qcow2"

#### only available in intranet
if [[ -n "$IntranetBaseUrl" ]]; then
	guestARCH=$(case $GuestARCH in
		(x86_64) echo amd64;;
		(aarch64) echo arm64-aarch64;;
		(riscv64|riscv) echo riscv-riscv64;;
		esac
	)
	distroInfo[FreeBSD-14.0]="$IntranetBaseUrl/vm-images/FreeBSD-14.0/FreeBSD-14.0-RELEASE-${guestARCH}.qcow2.xz"
	distroInfo[FreeBSD-13.2]="$IntranetBaseUrl/vm-images/FreeBSD-13.2/FreeBSD-13.2-RELEASE-${guestARCH}.qcow2.xz"
	distroInfo[FreeBSD-13.1]="$IntranetBaseUrl/vm-images/FreeBSD-13.1/FreeBSD-13.1-RELEASE-${guestARCH}.qcow2.xz"
	distroInfo[FreeBSD-13.0]="$IntranetBaseUrl/vm-images/FreeBSD-13.0/FreeBSD-13.0-RELEASE-${guestARCH}.qcow2.xz"
	distroInfo[FreeBSD-12.4]="$IntranetBaseUrl/vm-images/FreeBSD-12.4/FreeBSD-12.4-RELEASE-${guestARCH}.qcow2.xz"

	if [[ "$GuestARCH" = x86_64 ]]; then
		for _d in RHEL-7.{1..2} RHEL-6.{0..10} RHEL5-Server-U{10..11}; do
			distroInfo[$_d]="$IntranetBaseUrl/vm-images/$_d/"
		done
		distroInfo[Windows-server-2022]="cdrom:$IntranetBaseUrl/windows-images/Win2022-Evaluation.iso"
		distroInfo[Windows-server-2019]="cdrom:$IntranetBaseUrl/windows-images/Win2019-Evaluation.iso"
		distroInfo[Windows-server-2016]="cdrom:$IntranetBaseUrl/windows-images/Win2016-Evaluation.iso"
		distroInfo[Windows-server-2012r2]="cdrom:$IntranetBaseUrl/windows-images/Win2012r2-Evaluation.iso"
		distroInfo[Windows-11]="cdrom:$IntranetBaseUrl/windows-images/Win11-Evaluation.iso"
		distroInfo[Windows-10]="cdrom:$IntranetBaseUrl/windows-images/Win10-Evaluation.iso"
		distroInfo[Windows-7]="cdrom:$IntranetBaseUrl/windows-images/Win7-cn.iso"
		distroInfo[Windows-7cn]="cdrom:$IntranetBaseUrl/windows-images/Win7-cn.iso"
		distroInfo[Windows-7en]="cdrom:$IntranetBaseUrl/windows-images/Win7-en.iso"
	fi
fi
