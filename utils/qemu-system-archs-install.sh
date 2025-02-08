#!/bin/bash
# this script is used to install qemu-system-${arch}

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

. /etc/os-release
OS=$NAME

case ${OS,,} in
slackware*)
	sbopkg-install.sh
	sbopkg_install() {
		local pkg=$1
		sudo /usr/sbin/sqg -p $pkg
		yes $'Q\nY\nP\nC' | sudo /usr/sbin/sbopkg -B -i $pkg
	}
	;;
red?hat|centos*|rocky*|alma*|anolis*)
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

#install qemu-system-*
for arch; do
	[[ "$arch" = -f ]] && { FORCE=yes; continue; } || archlist+="$arch "
done
[[ -z "$archlist" ]] && archlist="x86 aarch64 riscv ppc s390x"
pkglist=$(printf "qemu-system-%s " $archlist)
case ${OS,,} in
slackware*)
	/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install $pkglist
	;;
fedora*)
	yum $yumOpt install -y $pkglist
	yum $yumOpt install -y qemu-device-display-virtio-gpu-ccw
	;;
red?hat*|centos*|rocky*|alma*|anolis*)
	OSV=$(rpm -E %rhel)
	case "$OSV" in
	8|9|1[0-9])
		if [[ "$FORCE" = yes ]]; then
			yum-install-from-fedora.sh -rpm $pkglist qemu-device-display-virtio-gpu-ccw
		else
			yum-install-from-fedora.sh $pkglist qemu-device-display-virtio-gpu-ccw
		fi
		;;
	7)
		echo "{WARN} OS version is not supported, quit."; exit 1
		: <<-'COMM'
		#                          -26 or higher version will break RHEL-7
		yum-install-from-fedora.sh -24 -rpm $pkglist qemu-device-display-virtio-gpu-ccw
		yum-install-from-fedora.sh -28 edk2-aarch64
		COMM
		;;
	*)
		echo "{WARN} OS version is not supported, quit."; exit 1
		;;
	esac
	;;
debian*|ubuntu*)
	archlist="x86 arm ppc misc"
	pkglist=$(printf "qemu-system-%s " $archlist)
	apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y $pkglist
	;;
opensuse*|sles*)
	archlist="x86 arm ppc s390x"
	pkglist=$(printf "qemu-%s " $archlist)
	zypper in --no-recommends -y $pkglist
	;;
arch?linux)
	archlist="x86 aarch64 ppc s390x"
	pkglist=$(printf "qemu-system-%s " $archlist)
	pacman -Sy --noconfirm $pkglist
	;;
*)
	: #fixme add more platform
	;;
esac

rc=$?

#workaround for error:
# qemu-system-aarch64: unable to map backing store for guest RAM: Permission denied
setsebool -P domain_can_mmap_files=1

exit $rc
