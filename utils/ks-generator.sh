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
AuthConfigure="auth --passalgo=sha512 --useshadow"
PartConf=autopart
IgnoreDisk=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-url url> [-repo name1:url1 [-repo name2:url2 ...]] [-post <script>] [-sshkeyf <file>] [-kernel-opts=<params>] [-pkgs=<pkg1[ pkg2 ..]>] [--fstype=<ext4|xfs|...>]

	Example:
	 $0 -d centos-5 -url http://vault.centos.org/5.11/os/x86_64/
	 $0 -d centos-6 -url http://vault.centos.org/centos/6.10/os/x86_64/
	 $0 -d centos-7 -url http://vault.centos.org/centos/7/os/x86_64/
	 $0 -d centos-8 -url http://vault.centos.org/centos/8/BaseOS/x86_64/os/ --post post.sh --sshkeyf ~/.ssh/id_rsa.pub
	EOF
}

_at=`getopt -o hd: \
	--long help \
	--long url: \
	--long repo: \
	--long post: \
	--long fstype: \
	--long sshkeyf: \
	--long kernel-opts: --long kopts: \
	--long only-use: \
	--long pkgs: \
	--long append: \
	--long netn: \
	--long default-dns: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	--url)     URL="$2"; shift 2;;
	--repo)    Repos+=("$2"); shift 2;;
	--post)    Post="$2"; shift 2;;
	--fstype)  FSTYPE="$2"; PartConf+=\ --fstype=$FSTYPE; shift 2;;
	--sshkeyf) sshkeyf+=" $2"; shift 2;;
	--kernel-opts|--kopts) KernelOpts="$2"; shift 2;;
	--only-use) [[ -n "${2// /}" ]] && IgnoreDisk="ignoredisk --only-use=$2"; shift 2;;
	--pkgs)    PKGS=" $2"; shift 2;;
	--append)  APPEND="$2"; shift 2;;
	--netn)    NetN="$2"; shift 2;;
	--default-dns) defaultDNS="$2"; shift 2;;
	--) shift; break;;
	esac
done

[[ -z "$Distro" ]] && {
	Usage
	exit 1
}

NetN=${NetN:-1}

shopt -s nocasematch
case ${Distro,,} in
rhel-5*|rhel5*|centos5*|centos-5*)
	Packages="@base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"

	NetCommand=$(for ((i=0; i<NetN; i++)); do echo "network --device=eth$i --bootproto=dhcp"; done)
	KeyCommand="key --skip"
	Bootloader='bootloader --location=mbr --append="console=ttyS0,9600 rhgb quiet"'
	;;
rhel-6*|rhel6*|centos6*|centos-6*)
	Packages="-iwl* @base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"

	NetCommand=$(for ((i=0; i<NetN; i++)); do echo "network --device=eth$i --bootproto=dhcp"; done)
	KeyCommand="key --skip"
	;;
rhel-7*|rhel7*|centos7*|centos-7*)
	Packages="-iwl* @base @file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"
	;;
rhel-8*|rhel8*|centos8*|centos-8*|rocky8*|rocky-8*|alma8*|alma-8*)
	Packages="-iwl* @standard @file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"
	AuthConfigure=
	;;
rhel-9*|rhel9*|centos9*|centos-9*|rocky9*|rocky-9*|alma9*|alma-9*|anolis9*)
	Packages="-iwl* @standard @file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"
	AuthConfigure=
	;;
fedora*|rhel-1[0-9]*|rhel1[0-9]*|centos1[0-9]*|centos-1[0-9]*|rocky-1[0-9]*|rocky1[0-9]*|alma1[0-9]*|alma-1[0-9]*|anolis1[0-9]*)
	Packages="-iwl* @standard @file-server redhat-lsb-core vim-enhanced git iproute screen wget bash-completion expect"
	AuthConfigure=
	;;
esac
shopt -u nocasematch

# output final ks cfg
Packages+=${PKGS}
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
$([[ -n "${URL}" ]] && echo "url --url=${URL}")
$KeyCommand
bootloader --location=mbr --append="rhgb quiet crashkernel=auto $KernelOpts"
$Bootloader
zerombr
clearpart --all --initlabel
$PartConf
$IgnoreDisk
$AuthConfigure
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

: <<'COMM'
#seems repo command is necessary on RHEL-8
for ((i=0; i < ${#Repos[@]}; i++)); do
	repo=${Repos[$i]}
	read name url <<<"${repo/:/ }"
	echo "repo --name=$name --baseurl=$url"

	#First two repos(BaseOS and AppStream) are enough, skip others
	[[ $i = 1 ]] && break
done
COMM

echo "$APPEND"

echo -e "\n%post --interpreter=/bin/bash"
for repo in "${Repos[@]}"; do
	if [[ "$repo" =~ ^[^:]+:(https|http|ftp|file):// ]]; then
		read name url _ <<<"${repo/:/ }"
	elif [[ "$repo" =~ ^(https|http|ftp|file):// ]]; then
		name=repo$((R++))
		url=$repo
	fi

	cat <<-EOF
	cat <<'REPO' >/etc/yum.repos.d/$name.repo
	[$name]
	name=$name
	baseurl=$url
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	sslverify=0
	metadata_expire=7d
	REPO

	EOF
done
echo -e "%end\n"

# post script
echo -e "%post --interpreter=/bin/bash --log=/root/extra-ks-post.log"
cat <<'DNFCONF'
grep -iq CentOS /etc/*-release && [[ $(rpm -E %rhel) -le 8 ]] && sed -ri -e 's/^mirror/#&/' -e '/^#baseurl/{s/^#//;s/mirrors?/vault/}' /etc/yum.repos.d/*
_dnfconf=$(test -f /etc/yum.conf && echo /etc/yum.conf || echo /etc/dnf/dnf.conf)
grep -q ^metadata_expire= $_dnfconf 2>/dev/null || echo metadata_expire=7d >>$_dnfconf
echo skip_if_unavailable=True >>/etc/dnf/dnf.conf
DNFCONF

cat <<'KSF'
ip a s eth1 2>/dev/null | awk -v rc=1 -v RS= '/eth1/&&!/inet/{rc=0}END{exit rc}' && {
	dhclient eth1 2>/dev/null
}
USER=$(id -un)
echo "[$USER@${HOSTNAME} ${HOME} $(pwd)] join wheel user to sudoers ..."
echo "%wheel        ALL=(ALL)       ALL" >> /etc/sudoers

echo "[$USER@${HOSTNAME} ${HOME} $(pwd)] fix CentOS-5 repo ..."
ver=$(LANG=C rpm -q --qf %{version} centos-release)
[[ "$ver" = 5* ]] && sed -i -e 's;mirror.centos.org/centos;vault.centos.org;' -e 's/^mirror/#&/' -e 's/^#base/base/' /etc/yum.repos.d/*
[[ "$ver" = 5 ]] && sed -i -e 's;\$releasever;5.11;' /etc/yum.repos.d/*

sed -ri -e '/^#?(PasswordAuthentication|AllowAgentForwarding|PermitRootLogin) (.*)$/{s//\1 yes/}' /etc/ssh/sshd_config $(ls /etc/ssh/sshd_config.d/*)
grep -q '^StrictHostKeyChecking no' /etc/ssh/ssh_config || echo "StrictHostKeyChecking no" >>/etc/ssh/ssh_config
KSF

[[ -n "$sshkeyf" ]] && {
	cat <<-KSF
	echo "[\$USER@\${HOSTNAME} \${HOME} \$(pwd)] inject sshkey ..."
	USERS="root foo bar"
	for U in \$USERS; do
		H=\$(getent passwd "\$U" | awk -F: '{print \$6}')
		mkdir -p \$H/.ssh && echo "$(for F in $sshkeyf; do tail -n1 $F; done)" >>\$H/.ssh/authorized_keys
	done
	KSF
}

[[ -n "$Post" && -f "$Post" ]] && {
	cat $Post
}

cat <<'DNS_DOMAIN'
hostn=$(hostname); domain=${hostn#*.}; grep -q "search .* ${domain}" /etc/resolv.conf && sed -i -e "/^search/{s/ ${domain}//;s/search/& ${domain}/}" /etc/resolv.conf
DNS_DOMAIN
[[ -n "$defaultDNS" ]] && cat <<DNS
grep -q systemd-resolved /etc/resolv.conf || { sed -i -e "/$defaultDNS/d" -e "0,/nameserver/s//nameserver $defaultDNS\n&/" /etc/resolv.conf; sed -ri '/^\[main]/s//&\ndns=none\nrc-manager=unmanaged/' /etc/NetworkManager/NetworkManager.conf; }
cp /etc/resolv.conf{,.new}
DNS

cat <<EOF
echo "export DISTRO=$Distro DISTRO_BUILD=$Distro RSTRNT_OSDISTRO=$Distro" >>/etc/bashrc
%end
EOF

case $Distro in
RHEL-5*|RHEL5*|centos5*|centos-5*)
	cat <<-PKG

	%packages --ignoremissing
	${Packages}
	PKG
	;;
esac
