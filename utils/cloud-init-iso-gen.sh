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
baseUrl=https://raw.githubusercontent.com/tcler/kiss-vm-ns/master
downhostname=${_downhostname/fedora/red}
bkrClientImprovedUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master
KernelOpts=

is_available_url() {
        local _url=$1
        curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail $_url &>/dev/null
}
is_rh_intranet() {
	local iurl=http://$downhostname
	is_available_url $iurl
}

Usage() {
	cat <<-EOF >&2
	Usage: $0 <iso file path> [--hostname name] [--repo name:url [--repo name:url]] [-b|--brewinstall "pkg list"] [-p|--pkginstall "pkg list"] [--kdump] [--fips] [--kopts=<args>]
	EOF
}

_at=`getopt -o hp:b:D \
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
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-D|--debug) DEBUG=yes; shift 1;;
	--hostname) HostName="$2"; shift 2;;
	--repo) Repos+=($2); shift 2;;
	-p|--pkginstall) PKGS="$2"; shift 2;;
	-b|--brewinstall) BPKGS="$2"; shift 2;;
	--sshkeyf) sshkeyf+=" $2"; shift 2;;
	--kdump) kdump=yes; shift 1;;
	--fips) fips=yes; shift 1;;
	--kernel-opts|--kopts) KernelOpts="$2"; shift 2;;
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

is_rh_intranet && {
	Intranet=yes
	baseUrl=http://$downhostname/qa/rhts/lookaside/kiss-vm-ns
	bkrClientImprovedUrl=http://$downhostname/qa/rhts/lookaside/bkr-client-improved
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

REPO
done
)

runcmd:
  - test -f /etc/dnf/dnf.conf && { ln -s /usr/bin/{dnf,yum}; }
  - sed -ri -e '/^#?(PasswordAuthentication|AllowAgentForwarding|PermitRootLogin) (.*)$/{s//\1 yes/}' -e '/^Inc/s@/\*.conf@/*redhat.conf@' /etc/ssh/sshd_config $(ls /etc/ssh/sshd_config.d/*) && service sshd restart || systemctl restart sshd
  - echo net.ipv4.conf.all.rp_filter=2 >>/etc/sysctl.conf && sysctl -p
  - command -v yum && yum install -y bash-completion curl wget vim ipcalc $PKGS
  -   command -v apt && { apt update -y; apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y bash-completion curl wget vim ipcalc $PKGS; }
  -   command -v zypper && zypper in --no-recommends -y bash-completion curl wget vim ipcalc $PKGS
  -   command -v pacman && { pacman -Sy --noconfirm archlinux-keyring && pacman -Su --noconfirm; }
  -   command -v pacman && pacman -S --needed --noconfirm bash-completion curl wget vim ipcalc $PKGS
$(
[[ $Intranet = yes ]] && cat <<IntranetCMD
  - command -v yum && curl -L -k -m 30 -o /usr/bin/brewinstall.sh "$bkrClientImprovedUrl/utils/brewinstall.sh" &&
    chmod +x /usr/bin/brewinstall.sh && brewinstall.sh $(for b in $BPKGS; do echo -n "'$b' "; done) -noreboot
IntranetCMD
[[ $Intranet = yes && "$RESTRAINT" = yes ]] && cat <<Restraint
  - command -v yum && yum install -y restraint-rhts  beakerlib && systemctl start restraintd
Restraint
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
[[ -n "$KernelOpts" ]] && cat <<KDUMP
  - grubby --args="$KernelOpts" --update-kernel=DEFAULT
KDUMP
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
