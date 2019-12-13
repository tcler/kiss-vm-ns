#!/bin/bash
#
# get simple template from here:
#  https://access.redhat.com/labs/kickstartconfig
# and replace some info in the template

Distro=
URL=
Repos=()
Post=
NetCommand=
KeyCommand=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-url url> [-repo name1:url1 [-repo name2:url2 ...]] [-post <script>] [-sshkeyf <file>]

	Example:
	 $0 -d centos-5 -url http://vault.centos.org/5.11/os/x86_64/
	 $0 -d centos-6 -url http://mirror.centos.org/centos/6.10/os/x86_64/
	 $0 -d centos-7 -url http://mirror.centos.org/centos/7/os/x86_64/
	 $0 -d centos-8 -url http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ --post post.sh --sshkeyf ~/.ssh/id_rsa.pub
	EOF
}

_at=`getopt -o hd: \
	--long help \
	--long url: \
	--long repo: \
	--long post: \
	--long sshkeyf: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	--url)     URL="$2"; shift 2;;
	--repo)    Repos+=("$2"); shift 2;;
	--post)    Post="$2"; shift 2;;
	--sshkeyf) sshkeyf="$2"; shift 2;;
	--) shift; break;;
	esac
done

[[ -z "$Distro" || -z "$URL" ]] && {
	Usage
	exit 1
}

shopt -s nocasematch
case $Distro in
RHEL-5*|RHEL5*|centos5*|centos-5*)
	Packages="@base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen wget"

	NetCommand="network --device=eth0 --bootproto=dhcp"
	KeyCommand="key --skip"
	Bootloader='bootloader --location=mbr --append="console=ttyS0,9600 rhgb quiet"'
	EPEL=http://archive.fedoraproject.org/pub/archive/epel/epel-release-latest-5.noarch.rpm
	;;
RHEL-6*|RHEL6*|centos6*|centos-6*)
	Packages="-iwl* @base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen wget"

	NetCommand="network --device=eth0 --bootproto=dhcp"
	KeyCommand="key --skip"
	EPEL=http://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
	;;
RHEL-7*|RHEL7*|centos7*|centos-7*)
	Packages="-iwl* @base @file-server redhat-lsb-core vim-enhanced git iproute screen wget"
	EPEL=http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	;;
RHEL-8*|RHEL8*|centos8*|centos-8*|Fedora-*)
	Packages="-iwl* @standard @file-server redhat-lsb-core vim-enhanced git iproute screen wget"
	EPEL=http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
	;;
esac
shopt -u nocasematch

# output final ks cfg
Packages=${Packages// /$'\n'}

cat <<KSF
lang en_US
keyboard us
timezone Asia/Shanghai --isUtc
rootpw \$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1 --iscrypted

user --name=foo --groups=wheel --iscrypted --password=\$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1
user --name=bar --iscrypted --password=\$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1

#platform x86, AMD64, or Intel EM64T
reboot
$NetCommand
text
url --url=$URL
$KeyCommand
bootloader --location=mbr --append="rhgb quiet crashkernel=auto"
$Bootloader
zerombr
clearpart --all --initlabel
autopart
auth --passalgo=sha512 --useshadow
selinux --enforcing
firewall --enabled --http --ftp --smtp --ssh
skipx
firstboot --disable
KSF

case $Distro in
RHEL-5*|RHEL5*|centos5*|centos-5*)
	:;;
*)
	cat <<-PKG

	%packages --ignoremissing
	${Packages}
	%end

	PKG
	;;
esac

for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	echo "repo --name=$name --baseurl=$url"
done

echo -e "\n%post"

# There's been repo files in CentOS by default, so clear Repos array
[[ $URL = *centos* ]] && Repos=()

for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	cat <<-EOF
	cat <<REPO >/etc/yum.repos.d/$name.repo
	[$name]
	name=$name
	baseurl=$url
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	REPO

	EOF
done
echo -e "%end\n"

# post script
echo -e "%post --log=/root/extra-ks-post.log"
cat <<'KSF'
USER=$(id -un)
echo "[$USER@${HOSTNAME} ${HOME} $(pwd)] set dnf strict=0 ..."
test -f /etc/dnf/dnf.conf && echo strict=0 >>/etc/dnf/dnf.conf

echo "[$USER@${HOSTNAME} ${HOME} $(pwd)] join wheel user to sudoers ..."
echo "%wheel        ALL=(ALL)       ALL" >> /etc/sudoers

echo "[$USER@${HOSTNAME} ${HOME} $(pwd)] fix CentOS-5 repo ..."
ver=$(LANG=C rpm -q --qf %{version} centos-release)
[[ "$ver" = 5* ]] && sed -i -e 's;mirror.centos.org/centos;vault.centos.org;' -e 's/^mirror/#&/' -e 's/^#base/base/' /etc/yum.repos.d/*
[[ "$ver" = 5 ]] && sed -i -e 's;\$releasever;5.11;' /etc/yum.repos.d/*
KSF
cat <<KSF
echo "[\$USER@\${HOSTNAME} \${HOME} \$(pwd)] yum install $EPEL ..."
wget $EPEL --no-check-certificate
rpm -ivh --force ${EPEL##*/}
KSF

[[ -n "$sshkeyf" ]] && {
	cat <<-KSF
	echo "[\$USER@\${HOSTNAME} \${HOME} \$(pwd)] inject sshkey ..."
	USERS="root foo bar"
	for U in \$USERS; do
		H=\$(getent passwd "\$U" | awk -F: '{print \$6}')
		mkdir \$H/.ssh && echo "$(tail -n1 $sshkeyf)" >>\$H/.ssh/authorized_keys
	done
	KSF
}

[[ -n "$Post" && -f "$Post" ]] && {
	cat $Post
}
echo -e "%end\n"

case $Distro in
RHEL-5*|RHEL5*|centos5*|centos-5*)
	cat <<-PKG

	%packages --ignoremissing
	${Packages}
	PKG
	;;
esac
