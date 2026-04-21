declare -A distroInfo

GuestARCH=${GuestARCH:-$(uname -m)}
_GuestARCH=${GuestARCH}; [[ "$GuestARCH" = ppc64 ]] && _GuestARCH=ppc64le;
Country=$(timeout 2 curl -s ipinfo.io/country)

#### CentOS stream and CentOS
distroInfo[Alma-10]="https://repo.almalinux.org/almalinux/10/cloud/$_GuestARCH/images/AlmaLinux-10-GenericCloud-latest.$_GuestARCH.qcow2 https://repo.almalinux.org/almalinux/10/BaseOS/$_GuestARCH/os/"
distroInfo[Alma-9]="https://repo.almalinux.org/almalinux/9/cloud/$_GuestARCH/images/AlmaLinux-9-GenericCloud-latest.$_GuestARCH.qcow2 https://repo.almalinux.org/almalinux/9/BaseOS/$_GuestARCH/os/"
distroInfo[Alma-8]="https://repo.almalinux.org/almalinux/8/cloud/$_GuestARCH/images/AlmaLinux-8-GenericCloud-latest.$_GuestARCH.qcow2 https://repo.almalinux.org/almalinux/8/BaseOS/$_GuestARCH/os/"

distroInfo[Rocky-10]="https://mirrors.sdu.edu.cn/rocky/10/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/10/BaseOS/$_GuestARCH/os"
distroInfo[Rocky-9]="https://mirrors.sdu.edu.cn/rocky/9/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/9/BaseOS/$_GuestARCH/os"
distroInfo[Rocky-8]="https://mirrors.sdu.edu.cn/rocky/8/images/$_GuestARCH/%%GenericCloud.*.qcow2 https://mirrors.sdu.edu.cn/rocky/8/BaseOS/$_GuestARCH/os"

distroInfo[CentOS-10-stream]="https://composes.stream.centos.org/stream-10/production/latest-CentOS-Stream/compose/BaseOS/$_GuestARCH/images/"
distroInfo[CentOS-9-stream]="https://cloud.centos.org/centos/9-stream/$_GuestARCH/images/ http://mirror.stream.centos.org/9-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8-stream]="https://cloud.centos.org/centos/8-stream/$_GuestARCH/images/ http://vault.centos.org/centos/8-stream/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-8]="https://cloud.centos.org/centos/8/$_GuestARCH/images/ http://vault.centos.org/centos/8/BaseOS/$_GuestARCH/os/"
distroInfo[CentOS-7]="https://cloud.centos.org/centos/7/images/%%GenericCloud-.{4}.qcow2c http://vault.centos.org/centos/7/os/$_GuestARCH/"

#### Fedora
fbaseurl=https://download.fedoraproject.org/pub/fedora/linux
lstv=44
for fv in rawhide $((lstv+1)); do distroInfo[f$fv]=$fbaseurl/development/$fv/Cloud/$GuestARCH/images/; done
eval "for fv in {$((lstv-4))..$lstv}"'; do distroInfo[f$fv]=$fbaseurl/releases/$fv/Cloud/$GuestARCH/images/; done'
distroInfo[frawhide]="https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Cloud/${GuestARCH}/images/%%Generic.*.qcow2"

#### Debian/Ubuntu
# https://cloud.debian.org/images/openstack/testing/
# https://cloud.debian.org/images/openstack/$latestVersion/
# https://cloud.debian.org/images/openstack/archive/$olderVersion/
distroInfo[debian-13]="https://cloud.debian.org/images/cloud/trixie/latest/"
distroInfo[debian-12]="http://cloud.debian.org/images/cloud/bookworm/latest/"
distroInfo[debian-11]="http://cloud.debian.org/images/cloud/bullseye/latest/"
distroInfo[debian-10]="https://cloud.debian.org/images/openstack/current-10/debian-10-openstack-${GuestARCH/x86_64/amd64}.qcow2"
distroInfo[debian-9]="https://cloud.debian.org/images/openstack/current-9/debian-9-openstack-${GuestARCH/x86_64/amd64}.qcow2"
lyy=$(date +%y -d '-1year'); llyy=$(date +%y -d '-2year'); read yy MM < <(date +%y\ %m); uvers=()
if [[ ${MM#0} -gt 10 ]]; then uvers+=(${yy}.{10,04}); elif [[ ${MM#0} -gt 4 ]]; then uvers+=(${yy}.04); fi
uvers+=(${lyy}.{10,04} ${llyy}.{10,04})
for uver in ${uvers[@]}; do
	distroInfo[ubuntu-${uver}]="https://cloud-images.ubuntu.com/releases/${uver}/release/ubuntu-${uver}-server-cloudimg-${GuestARCH/x86_64/amd64}.img"
done

#### OpenSUSE
distroInfo[openSUSE-leap-15.6]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.5]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.4]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.3]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.3/images/openSUSE-Leap-15.3.$GuestARCH-NoCloud.qcow2"
distroInfo[openSUSE-leap-15.2]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.2/images/openSUSE-Leap-15.2-OpenStack.$GuestARCH.qcow2"

#### FreeBSD
distroInfo[FreeBSD-15.0]="https://download.freebsd.org/ftp/releases/VM-IMAGES/15.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}-zfs.qcow2.xz"
distroInfo[FreeBSD-14.4]="https://download.freebsd.org/ftp/releases/VM-IMAGES/14.4-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-14.3]="https://download.freebsd.org/ftp/releases/VM-IMAGES/14.3-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"
distroInfo[FreeBSD-13.5]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.5-RELEASE/${GuestARCH/x86_64/amd64}/Latest/%%${GuestARCH/x86_64/amd64}.qcow2.xz"

#### ArchLinux
distroInfo[archlinux]="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-${GuestARCH}-cloudimg.qcow2"
distroInfo[archlinux]="https://linuximages.de/openstack/arch/arch-openstack-LATEST-image-bootstrap${GuestARCH/x86_64/}.qcow2"

case "$Country" in
CN|HK)
	#### Alma and Rocky
	aliBaseUrl=https://mirrors.aliyun.com/almalinux
	sjtuBaseUrl=https://mirrors.sjtug.sjtu.edu.cn/almalinux
	baseUrl=$sjtuBaseUrl
	distroInfo[Alma-10]="$baseUrl/10/cloud/${_GuestARCH}/images/AlmaLinux-10-GenericCloud-latest.${_GuestARCH}.qcow2"
	distroInfo[Alma-9]="$baseUrl/9/cloud/${_GuestARCH}/images/AlmaLinux-9-GenericCloud-latest.${_GuestARCH}.qcow2"
	distroInfo[Alma-8]="$baseUrl/8/cloud/${_GuestARCH}/images/AlmaLinux-8-GenericCloud-latest.${_GuestARCH}.qcow2"

	distroInfo[Rocky-10]="https://mirrors.sdu.edu.cn/rocky/10/images/$_GuestARCH/%%GenericCloud.*.qcow2"
	distroInfo[Rocky-9]="https://mirrors.sdu.edu.cn/rocky/9/images/$_GuestARCH/%%GenericCloud.*.qcow2"
	distroInfo[Rocky-8]="https://mirrors.sdu.edu.cn/rocky/8/images/$_GuestARCH/%%GenericCloud.*.qcow2"

	#### Fedora
	lstv=44
	fbaseurl=https://mirrors.ustc.edu.cn/fedora/releases
	fbaseurl=https://mirrors.aliyun.com/fedora/releases
	eval "for fv in {$((lstv-4))..$lstv}"'; do distroInfo[f$fv]=$fbaseurl/$fv/Cloud/$GuestARCH/images/; done'

	#### Debian
	distroInfo[debian-13]="https://mirror.sjtu.edu.cn/debian-cdimage/cloud/trixie/latest/"
	distroInfo[debian-12]="https://mirror.sjtu.edu.cn/debian-cdimage/cloud/bookworm/latest/"
	distroInfo[debian-11]="https://mirror.sjtu.edu.cn/debian-cdimage/cloud/bullseye/latest/"

	#### OpenSUSE
	#distroInfo[openSUSE-leap-15.5]=""

	#### Arch Linux
	distroInfo[archlinux]="https://mirrors.bfsu.edu.cn/archlinux/images/latest/Arch-Linux-${GuestARCH}-cloudimg.qcow2"

	#### FreeBSD
	distroInfo[FreeBSD-15.0]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/15.0-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-15.0-RELEASE-${GuestARCH/x86_64/amd64}-zfs.qcow2.xz"
	distroInfo[FreeBSD-14.4]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/14.4-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-14.4-RELEASE-${GuestARCH/x86_64/amd64}.qcow2.xz"
	distroInfo[FreeBSD-14.3]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/14.3-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-14.3-RELEASE-${GuestARCH/x86_64/amd64}.qcow2.xz"
	distroInfo[FreeBSD-13.5]="https://mirrors.aliyun.com/freebsd/releases/VM-IMAGES/13.5-RELEASE/${GuestARCH/x86_64/amd64}/Latest/FreeBSD-13.5-RELEASE-${GuestARCH/x86_64/amd64}.qcow2.xz"
	;;
esac
