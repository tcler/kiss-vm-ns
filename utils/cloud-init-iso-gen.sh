#!/bin/bash
# author: yin-jianhong@163.com
# ref: https://cloudinit.readthedocs.io/en/latest/topics/examples.html

LANG=C
HostName=mylinux
Repos=()
BPKGS=
PKGS=
Intranet=no
_downhostname="download.devel.fedorahat.com"
downhostname=${_downhostname/fedora/red}
baseUrl=https://raw.githubusercontent.com/tcler/kiss-vm-ns/master
bkrClientImprovedUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master
KernelOpts=
LOOKASIDE_BASE_URL=${LOOKASIDE:-http://${downhostname}/qa/rhts/lookaside}

is_available_url() { local _url=$1; curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail $_url &>/dev/null; }
is_rh_intranet() { host ipa.corp.redhat.com &>/dev/null; }
is_rh_intranet2() { grep -q redhat.com /etc/resolv.conf || is_rh_intranet; }

Usage() {
	cat <<-EOF >&2
	Usage: $0 <iso file path> [--hostname name] [--repo name:url [--repo name:url]] [-b|--brewinstall "pkg list"] [-p|--pkginstall "pkg list"] [--kdump] [--fips] [--kopts=<args>]
	EOF
}

_at=`getopt -o hp:b:Dd: \
	--long help \
	--long debug \
	--long hostname: \
	--long repo: \
	--long pkginstall: \
	--long brewinstall: \
	--long sshkeyf: \
	--long kdump \
	--long fips \
	--long kernel-opts: --long kopts: \
	--long default-dns: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)         DISTRO="$2"; shift 2;;
	-D|--debug) DEBUG=yes; shift 1;;
	--hostname) HostName="$2"; shift 2;;
	--repo) Repos+=($2); shift 2;;
	-p|--pkginstall) PKGS="$2"; shift 2;;
	-b|--brewinstall) BPKGS="$2"; shift 2;;
	--sshkeyf) sshkeyf+=" $2"; shift 2;;
	--kdump) kdump=yes; shift 1;;
	--fips) fips=yes; shift 1;;
	--kernel-opts|--kopts) KernelOpts="$2"; shift 2;;
	--default-dns) defaultDNS="$2"; shift 2;;
	--) shift; break;;
	esac
done

isof=$1
if [[ -z "$isof" ]]; then
	Usage
	exit
else
	mkdir -p $(dirname $isof)
	touch $isof
	isof=$(readlink -f $isof)
fi

is_rh_intranet2 && {
	Intranet=yes
	baseUrl=${LOOKASIDE_BASE_URL}/kiss-vm-ns
	bkrClientImprovedUrl=${LOOKASIDE_BASE_URL}/bkr-client-improved
}

sshkeyf=${sshkeyf:-/dev/null}
tmpdir=/tmp/.cloud-init-iso-gen-$$
mkdir -p $tmpdir
pushd $tmpdir &>/dev/null

echo "local-hostname: ${HostName}" >meta-data

cat >user-data <<-EOF
#cloud-config
users:
  - default

  - name: root
    plain_text_passwd: redhat
    lock_passwd: false
    ssh_authorized_keys:
$(for F in $sshkeyf; do echo "      -" $(tail -n1 ${F}); done)

  - name: foo
    group: users, admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: redhat
    lock_passwd: false
    ssh_authorized_keys:
$(for F in $sshkeyf; do echo "      -" $(tail -n1 ${F}); done)

  - name: bar
    group: users, admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    plain_text_passwd: redhat
    lock_passwd: false
    ssh_authorized_keys:
$(for F in $sshkeyf; do echo "      -" $(tail -n1 ${F}); done)

chpasswd: { expire: False }

$(
[[ ${#Repos[@]} -gt 0 ]] && echo yum_repos:

for repo in "${Repos[@]}"; do
if [[ "$repo" =~ ^[^:]+:(https|http|ftp|file):// ]]; then
  read name url _ <<<"${repo/:/ }"
elif [[ "$repo" =~ ^(https|http|ftp|file):// ]]; then
  name=repo-$((R++))
  url=$repo
fi

cat <<REPO
  ${name}:
    name: $name
    baseurl: "$url"
    enabled: true
    gpgcheck: false
    skip_if_unavailable: true
    sslverify: 0
    metadata_expire: 7d

REPO
done
)

runcmd:
  - grep -iq CentOS /etc/*-release && [[ \$(rpm -E %rhel) -le 8 ]] && sed -ri -e 's/^mirror/#&/' -e '/^#baseurl/{s/^#//;s/mirrors?/vault/}' /etc/yum.repos.d/*
  - test -f /etc/dnf/dnf.conf && { ln -s /usr/bin/{dnf,yum}; echo skip_if_unavailable=True >>/etc/dnf/dnf.conf; }
  - ip a s eth1 2>/dev/null | awk -v rc=1 -v RS= '/eth1/&&!/inet/{rc=0}END{exit rc}' && { \
     dhclient eth1 2>/dev/null; \
  }
  - command -v yum && { \
     _dnfconf=\$(test -f /etc/yum.conf && echo /etc/yum.conf || echo /etc/dnf/dnf.conf); \
     grep -q ^metadata_expire= \$_dnfconf 2>/dev/null || echo metadata_expire=7d >>\$_dnfconf; \
  }
  - sed -ri -e '/^#?(PasswordAuthentication|AllowAgentForwarding|PermitRootLogin) (.*)$/{s//\1 yes/}' -e '/^Inc/s@/\*.conf@/*redhat.conf@' /etc/ssh/sshd_config \$(ls /etc/ssh/sshd_config.d/*) && service sshd restart || systemctl restart sshd
  - grep -q '^StrictHostKeyChecking no' /etc/ssh/ssh_config || echo "StrictHostKeyChecking no" >>/etc/ssh/ssh_config
  - echo net.ipv4.conf.all.rp_filter=2 >>/etc/sysctl.conf && sysctl -p
  - grep -q ^nameserver /etc/resolv.conf || { if=\$(ip -br a|tail -1|cut -d" " -f1); cn=\$(nmcli -g GENERAL.CONNECTION device show \$if); nmcli connection modify "\${cn}" ipv4.ignore-auto-dns yes; nmcli connection up "\${cn}"; systemctl restart NetworkManager; }
  - command -v yum && yum --setopt=strict=0 install -y bash-completion curl wget vim ipcalc expect $PKGS
  -   command -v apt && { apt update -y; apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion curl wget vim ipcalc expect network-manager $PKGS; systemctl restart NetworkManager; }
  -   command -v zypper && { zypper in --no-recommends -y bash-completion curl wget vim ipcalc expect NetworkManager $PKGS; systemctl restart NetworkManager; }
  -   command -v pacman && { pacman -Sy --noconfirm archlinux-keyring && pacman -Su --noconfirm; pacman-key --init; pacman-key --populate; }
  -   command -v pacman && { pacman -S --needed --noconfirm bash-completion curl wget vim ipcalc expect networkmanager $PKGS; systemctl restart NetworkManager; }
  - echo "export DISTRO=$Distro DISTRO_BUILD=$Distro RSTRNT_OSDISTRO=$Distro" >>/etc/bashrc
$(
if [[ $Intranet = yes ]]; then
cat <<IntranetCMD
  - (cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt,mtls-ca-validators.crt,RH-IT-Root-CA.crt} && update-ca-trust)
  - command -v yum && (cd /usr/bin && curl -L -k -m 30 --remote-name-all $bkrClientImprovedUrl/utils/{brewinstall.sh,taskfetch.sh} $baseUrl/utils/srcrpmbuild.sh && chmod +x brewinstall.sh taskfetch.sh srcrpmbuild.sh) &&
    { brewinstall.sh $(for b in $BPKGS; do echo -n "'$b' "; done) -noreboot; [[ "$TASK_FETCH" = yes ]] && taskfetch.sh --install-deps; }

  - _rpath=share/restraint/plugins/task_run.d
  - command -v yum && { yum --setopt=strict=0 install -y restraint-rhts  beakerlib && systemctl start restraintd;
    (cd /usr/\$_rpath && curl -k -Ls --remote-name-all $bkrClientImprovedUrl/\$_rpath/{25_environment,27_task_require} && chmod a+x *);
    (cd /usr/\${_rpath%/*}/completed.d && curl -k -Ls -O $bkrClientImprovedUrl/\${_rpath%/*}/completed.d/85_sync_multihost_tasks && chmod a+x *); }

IntranetCMD
elif [[ "$TASK_FETCH" = yes ]]; then
cat <<TaskFetch
  - command -v yum && (cd /usr/bin && curl -L -k -m 30 -O "$bkrClientImprovedUrl/utils/taskfetch.sh" && chmod +x taskfetch.sh) &&
    { taskfetch.sh --install-deps; }
TaskFetch
fi
)
$(
[[ "$fips" = yes ]] && cat <<FIPS
  - command -v yum && curl -L -k -m 30 -o /usr/bin/enable-fips.sh "$baseUrl/utils/enable-fips.sh" &&
    chmod +x /usr/bin/enable-fips.sh && enable-fips.sh
FIPS
)
$(
[[ "$kdump" = yes ]] && cat <<KDUMP
  - command -v yum && curl -L -k -m 30 -o /usr/bin/kdump-setup.sh "$baseUrl/utils/kdump-setup.sh" &&
    chmod +x /usr/bin/kdump-setup.sh && kdump-setup.sh
KDUMP
)
$(
[[ -n "$KernelOpts" ]] && cat <<KOPTS
  - grubby --args="$KernelOpts" --update-kernel=DEFAULT
KOPTS
)
$(
cat <<DNS_DOMAIN
  - hostn=\$(hostname); domain=\${hostn#*.}; grep -q "search .* \${domain}" /etc/resolv.conf && sed -i -e "/^search/{s/ \${domain}//;s/search/& \${domain}/}" /etc/resolv.conf
  - grep -q ^nameserver /etc/resolv.conf || { if=\$(ip -br a|tail -1|cut -d" " -f1); cn=\$(nmcli -g GENERAL.CONNECTION device show \$if); nmcli connection modify "\${cn}" ipv4.ignore-auto-dns yes; nmcli connection up "\${cn}"; systemctl restart NetworkManager; }
DNS_DOMAIN
[[ -n "$defaultDNS" ]] && cat <<DNS
  - grep -q systemd-resolved /etc/resolv.conf || { sed -i -e "/$defaultDNS/d" -e "0,/nameserver/s//nameserver $defaultDNS\n&/" /etc/resolv.conf; sed -ri '/^\[main]/s//&\ndns=none\nrc-manager=unmanaged/' /etc/NetworkManager/NetworkManager.conf; }
  - cp /etc/resolv.conf{,.new}
DNS
)
$(
[[ "$kdump" = yes || "$fips" = yes || -n "$BPKGS" || -n "$KernelOpts" ]] && cat <<REBOOT
  - reboot
REBOOT
)
EOF

GEN_ISO_CMD=genisoimage
command -v $GEN_ISO_CMD 2>/dev/null || GEN_ISO_CMD=mkisofs
$GEN_ISO_CMD -output $isof -volid cidata -joliet -rock user-data meta-data

popd &>/dev/null

[[ -n "$DEBUG" ]] && cat $tmpdir/*
rm -rf $tmpdir
