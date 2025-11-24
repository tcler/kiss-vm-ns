#!/bin/bash
# author: Jianhong Yin <yin-jianhong@163.com>
# configure nfs service and start

export LANG=C

## global var
PREFIX=/nfsshare
NFSROOT=

## argparse
P=${0##*/}
Usage() {
	cat <<EOF
Usage:
  sudo $P [options]

Options:
  -h, -help              ; show this help
  -prefix <path>         ; root directory of nfs share(default: /nfsshare/)
  -nfsroot <path>        ; optional exports dir with fsid=0
  -t                     ; run extra tests after nfs start
  -no-tlshd              ; don't configure tlshd
  -owner <owner>         ; owner of the export dirs
EOF
}
test `id -u` = 0 || { echo "{Warn} This command has to be run under the root user"|grep --color=always . >&2; Usage >&2; exit 1; }

srun() {
	local cmdline=$1 expect_ret=${2:-0} comment=${3}
	local ret=0
	_lcontains() { [[ "${1//,/ }" =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1; }
	echo $'\E[0;33;44m'"[$(date +%T) $USER@ ${PWD%%*/}]> $cmdline"$'\E[0m'
	eval $cmdline
	ret=$?
	[[ $expect_ret != - ]] && ! _lcontains ${expect_ret} $ret && {
		echo $'\E[41m'"${comment:-{error} expected $expect_ret, but get $ret}"$'\E[0m' >&2
		let retcode++
	}
	return $ret
}


_at=$(getopt -a -o ht \
	--long help \
	--long test \
	--long prefix: \
	--long nfsroot: \
	--long no-tlshd \
	--long owner: \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)    Usage; shift 1; exit 0;;
	-t|--test)    eTEST=yes; shift 1;;
	--prefix)     PREFIX=${2:-${PREFIX}}; shift 2;;
	--nfsroot)    NFSROOT=${2}; shift 2;;
	--no-tlshd)   TLSHD=no; shift 1;;
	--owner)      OWNER=${2}; shift 2;;
	--) shift; break;;
	esac
done

if [[ -n "${NFSROOT}" && "${NFSROOT}" != /* ]]; then
	echo "{ERROE} nfsroot must be a absolute path(start with '/')" >&2
	exit 1
fi
if [[ -z "${NFSROOT}" ]] && stat /run/ostree-booted &>/dev/null; then
	NFSROOT=/var
fi

## install related packages
rpm -q nfs-utils || yum install -y nfs-utils &>/dev/null
if [[ "$TLSHD" != no ]] && rpm -q ktls-utils --quiet &&
    grep -wq mtls <(man exports) && [[ $(uname -r) > 5.14.0-4 ]]; then
	yum install -y ktls-utils &>/dev/null
fi
#yum install -y krb5-workstation &>/dev/null


## create nfs export directorys
mkdir -p $NFSROOT/$PREFIX/{ro,rw,async,labelled-nfs,qe,devel,tls,mtls}
chgrp nobody -R $NFSROOT/$PREFIX
chmod g+ws -R $NFSROOT/$PREFIX
touch $NFSROOT/$PREFIX/{ro,rw,async,labelled-nfs,qe,devel,tls,mtls}/testfile
for dir in $NFSROOT/$PREFIX/{ro,rw,async,labelled-nfs,qe,devel,tls,mtls}; do
	cp /etc/*.conf $dir/.
done
semanage fcontext -a -t nfs_t "$NFSROOT/$PREFIX(/.*)?"
restorecon -Rv $NFSROOT/$PREFIX
chmod 775 -R $NFSROOT/$PREFIX/{rw,async,labelled-nfs,qe,devel,tls,mtls}
if [[ -n "${OWNER}" ]]; then
	chown ${OWNER} -R $NFSROOT/$PREFIX
fi

## generate exports config file
defaultOpts=${defaultOpts:-insecure}
Squash=${Squash:-root_squash}
if [[ -d "${NFSROOT}" ]]; then
	echo "${NFSROOT} *(${defaultOpts},rw,sync,${Squash},crossmnt,fsid=0,no_subtree_check,sec=sys:krb5:krb5i:krb5p)" >/etc/exports
else
	: >/etc/exports
fi
cat <<EOF >>/etc/exports
$NFSROOT/$PREFIX/ro *(${defaultOpts},ro)
$NFSROOT/$PREFIX/rw *(${defaultOpts},rw,${Squash},sec=sys:krb5:krb5i:krb5p)
$NFSROOT/$PREFIX/async *(${defaultOpts},rw,${Squash},async,sec=sys:krb5:krb5i:krb5p)
$NFSROOT/$PREFIX/labelled-nfs *(${defaultOpts},rw,${Squash},security_label,sec=sys:krb5:krb5i:krb5p)
$NFSROOT/$PREFIX/qe *(${defaultOpts},rw,${Squash},sec=sys:krb5:krb5i:krb5p)
$NFSROOT/$PREFIX/devel *(${defaultOpts},rw,${Squash},sec=sys:krb5:krb5i:krb5p)
EOF
srun "cat /etc/exports"

## start nfs-server service
systemctl enable nfs-server
srun "systemctl restart nfs-server"
command -v firewall-cmd &>/dev/null &&
	srun "firewall-cmd --permanent --add-service={mountd,nfs,rpc-bind}; firewall-cmd --reload; :;"

## test/verify
srun "showmount -e localhost"

## config nfs tls support
OSV=$(rpm -E %rhel)
if [[ "$OSV" = 9 ]] && ! grep -wq mtls <(man exports); then
	mirrorList="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-39&arch=$(uname -m)"
	Country=$(timeout 2 curl -s ipinfo.io/country)
	case "$Country" in
	CN|HK)	frepo='http://ftp.iij.ad.jp/pub/linux/Fedora/archive/fedora/linux/releases/39/Everything/$basearch/os';;
	*)	frepo=$(curl -L -s "$mirrorList"|sed -n 2p);;
	esac
	yum install --nogpg --disablerepo="*" --repofrompath="f39,$frepo" -y --setopt=strict=0 --allowerasing nfs-utils
fi
if [[ "$TLSHD" != no ]] && rpm -q ktls-utils --quiet && grep -wq mtls <(man exports) && [[ $(uname -r) > 5.14.0-4 ]]; then
	cat <<-EOF >>/etc/exports
	$NFSROOT/$PREFIX/tls *(${defaultOpts},xprtsec=tls,rw,${Squash},sec=sys:krb5:krb5i:krb5p)
	$NFSROOT/$PREFIX/mtls *(${defaultOpts},xprtsec=mtls,rw,${Squash},sec=sys:krb5:krb5i:krb5p)
	EOF

	# Create a private key and obtain a certificate containing the Server's DNS name...
	crtf=/tmp/nfsd.crt
	keyf=/tmp/nfsd.key
	srun "openssl req -x509 -subj /CN=$HOSTNAME 
	    -addext subjectAltName=DNS:$HOSTNAME 
	    -addext keyUsage=digitalSignature 
	    -addext extendedKeyUsage=serverAuth 
	    -newkey rsa:2048 -noenc -sha256 -out $crtf -keyout $keyf"
	srun "openssl x509 -in $crtf -noout -checkhost $HOSTNAME" 0 "Check the certificate"
	srun "trust anchor $crtf" 0 "Add (server's) TLS certificate to the trust store"
	#srun "update-ca-trust"
	# Edit the /etc/tlshd.conf to use those created key and certificate..."
	cat >/etc/tlshd.conf <<-EOF
		[debug]
		loglevel=1
		tls=1
		nl=1

		[authenticate]
		#keyrings= <keyring>;<keyring>;<keyring>

		[authenticate.client]
		#x509.truststore=<pathname>
		x509.certificate=$crtf
		x509.private_key=$keyf

		[authenticate.server]
		#x509.truststore=<pathname>
		x509.certificate=$crtf
		x509.private_key=$keyf
	EOF
	srun "cat /etc/tlshd.conf" -
	srun "systemctl restart tlshd.service"
	srun "systemctl restart nfs-server.service"

	nfsmp=/mnt/nfsmp-$$
	srun "mkdir -p $nfsmp"
	srun "mount $HOSTNAME:${PREFIX}/tls $nfsmp -o xprtsec=tls"
	srun "umount $nfsmp"
	srun "mount $HOSTNAME:${PREFIX}/tls $nfsmp -o xprtsec=mtls"
	srun "umount $nfsmp"
fi

srun "showmount -e $HOSTNAME"

[[ "$eTEST" != yes ]] && exit

if [[ -z "$NFSROOT" ]]; then
	## one more test about nfsv4 pseudo-filesystem
	cat <<-EOF >/etc/systemd/system/home2.automount
	[Unit]
	Description=EFI System Partition Automount
	Documentation=TBD
	[Automount]
	Where=/home2
	TimeoutIdleSec=120
	EOF

	cat <<-EOF >/etc/systemd/system/home2.mount
	[Unit]
	Description=EFI System Partition Automount
	Documentation=TBD
	[Mount]
	What=/home
	Where=/home2
	Type=$(stat -f -c %T /home)
	Options=ro,bind
	EOF

	srun "systemctl daemon-reload"
	srun "systemctl start home2.automount"
	srun "systemctl status home2.mount | grep Active:" -

	nfsmp=/mnt/nfsmp-$$
	srun "mkdir -p $nfsmp"
	srun "mount localhost:/ $nfsmp"

	srun "uname -r"
	srun "touch $nfsmp/${PREFIX}/rw/file"
	srun "stat $nfsmp/${PREFIX}/rw/file"
	srun "ls -l $nfsmp $nfsmp/${PREFIX}/rw"
	srun "mount -t nfs,nfs4 | grep $nfsmp"
	srun "ls -l $nfsmp"

	srun "{ umount $nfsmp || umount -fl $nfsmp; } && rm -rf $nfsmp"

	srun "systemctl status home2.mount | grep Active:"
	srun "systemctl status home2.mount | grep mounted"
	srun "systemctl stop home2.automount"
	srun "mountpoint /home2" 32,1
fi
