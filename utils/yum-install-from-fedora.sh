#!/bin/bash
#
P=$0
switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

[[ $# < 1 || $1 = -h* ]] && {
	echo -e "\E[1;34mUsage: $P <pkgname1> [pkgname2 ...] [-\$fedora_version] [-rpm]\E[0m"
	exit 0
}

switchroot "$@"

#according:
#  https://docs.fedoraproject.org/en-US/quick-docs/fedora-and-red-hat-enterprise-linux/index.html
#  https://en.wikipedia.org/wiki/Red_Hat_Enterprise_Linux#RHEL_9
#if can not find pkg you want from default and epel repo, we can try from fedora repo:
#Red Hat Enterprise Linux 4	Nahant	2005-02-15	Fedora Core 3
#Red Hat Enterprise Linux 5	Tikanga	2007-03-14	Fedora Core 6
#Red Hat Enterprise Linux 6	Santiago	2010-11-10	Mix of Fedora 12 Fedora 13 and several modifications
#Red Hat Enterprise Linux 7	Maipo	2014-06-10	Primarily Fedora 19 with several changes from 20 and later
#Red Hat Enterprise Linux 8	Ootpa	2019-05-07	Fedora 28
#Red Hat Enterprise Linux 9	Plow	2022-05-17	Fedora 34

OSV=$(rpm -E %rhel)
arch=$(uname -m)
case "$OSV" in
6)	FEDORA_VER=$((13+2));;
7)	FEDORA_VER=$((20+2));;
8)	FEDORA_VER=$((28+1));;
9)	FEDORA_VER=$((34+2));;
*)	echo "{WARN} OS is not supported(This program is just for RHEL or RHEL-based OS), quit."; exit 1;;
esac

pkgs=()
for arg; do
	case $arg in
	-[0-9]*) fver=${arg#-}; fver=${fver#*=};;
	-rpm)    InstallType=rpm;;
	*)       pkgs+=("$arg");;
	esac
done
[[ -n "$fver" ]] && FEDORA_VER=$fver

#fedora_repo=https://dl.fedoraproject.org/pub/archive/fedora/linux/releases/${FEDORA_VER}/Everything/$arch/os/
mirrorList="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-${FEDORA_VER}&arch=$arch"
echo "{INFO} fedora-version: $FEDORA_VER, url: $mirrorList"

fedora_repo=$(curl -L -s "$mirrorList"|sed -n 3p)
frepon=fedora-${FEDORA_VER}
if [[ "$OSV" -le 7 ]]; then
	yum install -y yum-utils &>/dev/null
	trap 'rm -f /etc/yum.repos.d/${frepon}.repo' EXIT
	cat <<-REPO >/etc/yum.repos.d/${frepon}.repo
	[$frepon]
	name=Fedora
	#baseurl=$fedora_repo
	mirrorlist=$mirrorList
	enabled=0
	gpgcheck=0
	skip_if_unavailable=1
	REPO
fi

if [[ "$InstallType" != rpm ]]; then
	if [[ "$OSV" -le 7 ]]; then
		yum install --nogpg --disablerepo="*" --enablerepo="$frepon" -y --setopt=strict=0 "${pkgs[@]}"
	else
		yum install --nogpg --disablerepo="*" --repofrompath="$frepon,$fedora_repo" -y --setopt=strict=0 --allowerasing "${pkgs[@]}"
	fi
else
	tmpf=$(mktemp -d)
	mkdir -p $tmpf
	trap 'rm -rf $tmpf' EXIT
	if [[ "$OSV" -le 7 ]]; then
		pushd $tmpf
		yumdownloader --disablerepo=* --enablerepo=$frepon --setopt=strict=0 --destdir=$tmpf --resolve "${pkgs[@]}" --setopt=protected_multilib=false
		popd
	else
		yum install --nogpg --disablerepo="*" --repofrompath="$frepon,$fedora_repo" -y --setopt=strict=0 --downloadonly --destdir=$tmpf "${pkgs[@]}"
	fi
	rpm -ivh --force --nodeps $tmpf/*.rpm
fi
