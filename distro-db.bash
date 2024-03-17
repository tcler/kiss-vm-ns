declare -A distroInfo

GuestARCH=${GuestARCH:-$(uname -m)}
_GuestARCH=${GuestARCH}; [[ "$GuestARCH" = ppc64 ]] && _GuestARCH=ppc64le;
Country=$(timeout 2 curl -s ipinfo.io/country)

#### CentOS stream and CentOS
distroInfo[Alma-9]="https://repo.almalinux.org/almalinux/9/cloud/$_GuestARCH/images/AlmaLinux-9-GenericCloud-latest.$_GuestARCH.qcow2 https://repo.almalinux.org/almalinux/9/BaseOS/$_GuestARCH/os/"
distroInfo[Alma-8]="https://repo.almalinux.org/almalinux/8/cloud/$_GuestARCH/images/AlmaLinux-8-GenericCloud-latest.$_GuestARCH.qcow2 https://repo.almalinux.org/almalinux/8/BaseOS/$_GuestARCH/os/"

distroInfo[Rocky-9]="https://mirrors.sdu.edu.cn/rocky/9/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/9/BaseOS/$_GuestARCH/os"
distroInfo[Rocky-8]="https://mirrors.sdu.edu.cn/rocky/8/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/8/BaseOS/$_GuestARCH/os"

distroInfo[CentOS-9-stream]="https://cloud.centos.org/centos/9-stream/$_GuestARCH/images/ http://mirror.stream.centos.org/9-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8-stream]="https://cloud.centos.org/centos/8-stream/$_GuestARCH/images/ http://mirror.centos.org/centos/8-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8]="https://cloud.centos.org/centos/8/$_GuestARCH/images/ http://mirror.centos.org/centos/8/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-7]="https://cloud.centos.org/centos/7/images/%%GenericCloud-.{4}.qcow2c http://mirror.centos.org/centos/7/os/$_GuestARCH/"
distroInfo[CentOS-6]="https://cloud.centos.org/centos/6/images/%%GenericCloud.qcow2c http://mirror.centos.org/centos/6/os/$_GuestARCH/"

#### Fedora
fbaseurl=https://download.fedoraproject.org/pub/fedora/linux
lstv=39
for fv in rawhide $((lstv+1)); do distroInfo[f$fv]=$fbaseurl/development/$fv/Cloud/$GuestARCH/images/; done
eval "for fv in {$((lstv-4))..$lstv}"'; do distroInfo[f$fv]=$fbaseurl/releases/$fv/Cloud/$GuestARCH/images/; done'

#### Debian
# https://cloud.debian.org/images/openstack/testing/
# https://cloud.debian.org/images/openstack/$latestVersion/
# https://cloud.debian.org/images/openstack/archive/$olderVersion/
distroInfo[debian-13]="https://cloud.debian.org/images/cloud/trixie/daily/latest/"
distroInfo[debian-12]="http://cloud.debian.org/images/cloud/bookworm/latest/"
distroInfo[debian-11]="http://cloud.debian.org/images/cloud/bullseye/latest/"
distroInfo[debian-10]="https://cloud.debian.org/images/openstack/current-10/debian-10-openstack-${GuestARCH/x86_64/amd64}.qcow2"
distroInfo[debian-9]="https://cloud.debian.org/images/openstack/current-9/debian-9-openstack-${GuestARCH/x86_64/amd64}.qcow2"

#### OpenSUSE
distroInfo[openSUSE-leap-15.5]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.4]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.3]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.3/images/openSUSE-Leap-15.3.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.2]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.2/images/openSUSE-Leap-15.2-OpenStack.$GuestARCH.qcow2"

#### FreeBSD
distroInfo[FreeBSD-14.0-zfs]="https://download.freebsd.org/ftp/releases/VM-IMAGES/14.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}-zfs.qcow2.xz"
distroInfo[FreeBSD-14.0]="https://download.freebsd.org/ftp/releases/VM-IMAGES/14.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-13.3]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.3-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-13.2]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.2-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-12.4]="https://download.freebsd.org/ftp/releases/VM-IMAGES/12.4-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-15.0]="https://download.freebsd.org/ftp/snapshots/VM-IMAGES/15.0-CURRENT/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"

#### ArchLinux
distroInfo[archlinux]="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-${GuestARCH}-cloudimg.qcow2"
distroInfo[archlinux]="https://linuximages.de/openstack/arch/arch-openstack-LATEST-image-bootstrap${GuestARCH/x86_64/}.qcow2"

case "$Country" in
CN)
	#### CentOS stream and CentOS
	distroInfo[Alma-9]="https://mirrors.aliyun.com/almalinux/9/cloud/${_GuestARCH}/images/AlmaLinux-9-GenericCloud-latest.${_GuestARCH}.qcow2"
	distroInfo[Alma-8]="https://mirrors.aliyun.com/almalinux/8/cloud/${_GuestARCH}/images/AlmaLinux-8-GenericCloud-latest.${_GuestARCH}.qcow2"
	distroInfo[Rocky-9]="https://mirrors.sdu.edu.cn/rocky/9/images/$_GuestARCH/%%GenericCloud.*.qcow2"
	distroInfo[Rocky-8]="https://mirrors.sdu.edu.cn/rocky/8/images/$_GuestARCH/%%GenericCloud.*.qcow2"

	#### Fedora
	lstv=39
	fbaseurl=https://mirrors.ustc.edu.cn/fedora/releases
	eval "for fv in {$((lstv-4))..$lstv}"'; do distroInfo[f$fv]=$fbaseurl/$fv/Cloud/$GuestARCH/images/; done'

	#### Debian
	# https://cloud.debian.org/images/openstack/testing/
	# https://cloud.debian.org/images/openstack/$latestVersion/
	# https://cloud.debian.org/images/openstack/archive/$olderVersion/

	#### OpenSUSE
	#distroInfo[openSUSE-leap-15.5]=""

	#### FreeBSD
	distroInfo[FreeBSD-14.0-zfs]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/14.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-14.0-RELEASE-${GuestARCH/x86_64/amd64}-zfs.qcow2.xz"
	distroInfo[FreeBSD-14.0]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/14.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-14.0-RELEASE-${GuestARCH/x86_64/amd64}.qcow2.xz"
	;;
esac

#### only available in intranet
if [[ -n "$IntranetBaseUrl" ]]; then
	guestARCH=$(case $GuestARCH in
		(x86_64) echo amd64;;
		(aarch64) echo arm64-aarch64;;
		(riscv64|riscv) echo riscv-riscv64;;
		esac
	)
	distroInfo[FreeBSD-14.0-zfs]="$IntranetBaseUrl/vm-images/FreeBSD-14.0/FreeBSD-14.0-RELEASE-${guestARCH}-zfs.qcow2.xz"
	distroInfo[FreeBSD-14.0]="$IntranetBaseUrl/vm-images/FreeBSD-14.0/FreeBSD-14.0-RELEASE-${guestARCH}.qcow2.xz"
	distroInfo[FreeBSD-13.3]="$IntranetBaseUrl/vm-images/FreeBSD-13.3/FreeBSD-13.3-RELEASE-${guestARCH}.qcow2.xz"
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
