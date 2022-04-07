#!/bin/bash
# author: Jianhong Yin <yin-jianhong@163.com>
# configure samba service and start

export LANG=C

## global var
GROUP=MYGROUP
PREFIX=/smbshare
USERLIST=smbuser1,smbuser2
PASSWORD=redhat


## argparse
P=${0##*/}
Usage() {
	cat <<EOF
Usage:
  sudo $P [options]

Options:
  -h, -help              ; show this help
  -group <group name>    ; group name
  -users <user list>     ; comma separated samba user list(default: root,smbuser1,smbuser2)
  -passwd <passwd>       ; common password(default: redhat)
  -prefix <path>         ; root directory of samba share(default: /smbshare/)
  -fstype <type>         ; fs type of default samba share(/smbshare/)
EOF
}
test `id -u` = 0 || { echo "{Warn} This command has to be run under the root user"|grep --color=always . >&2; Usage >&2; exit 1; }

_at=$(getopt -a -o h \
	--long help \
	--long group: \
	--long prefix: \
	--long users: \
	--long passwd: \
	--long fstype: \
	-n "$P" -- "$@")
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)    Usage; shift 1; exit 0;;
	--group)      GROUP=$2; shift 2;;
	--prefix)     PREFIX=$2; shift 2;;
	--users)      USERLIST=$2; shift 2;;
	--passwd)     PASSWORD=$2; shift 2;;
	--fstype)     FSTYPE=$2; shift 2;;
	--) shift; break;;
	esac
done


## install related packages
yum install -y samba samba-common-tools >/dev/null
yum install -y samba-client cifs-utils tree >/dev/null

[[ "$FSTYPE" = ext4 ]] && {
	mkdir -p $PREFIX
	dd if=/dev/zero of=/sambashare.img bs=1M count=1000 status=progress
	mkfs.ext4 -F /sambashare.img
	mount -t ext4 -oloop /sambashare.img $PREFIX
}

## create smbusers and directorys
HOMEDIR=$PREFIX/homes
for user in ${USERLIST//,/ }; do
	useradd $user
	echo $PASSWORD | passwd --stdin $user
	echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -a -s $user

	homedir=$HOMEDIR/$user
	mkdir -vp $homedir
	chown $user $homedir
	chmod go-rwx $homedir
done

echo -e "$PASSWORD\n$PASSWORD" | smbpasswd -a -s root
mkdir -vp $PREFIX/{pub,upload}
chmod a+w $PREFIX/{pub,upload}
mkdir -vp $PREFIX/share
chcon -R -t samba_share_t $PREFIX


## generate smb config file
cat <<EOF >/etc/samba/smb.conf
[global]
    workgroup = $GROUP
    server string = Samba Server Version %v
   
    log file = /var/log/samba/log.%m
    max log size = 50
    security = user
    ntlm auth = yes

[homes]
    path = $HOMEDIR/%S
    public = no
    writable = yes
    readable = yes
    printable = no
    guest ok = no
    valid users = %S

[top]
    path = $PREFIX
    writeable = yes

[pub]
    path = $PREFIX/pub
    writable = yes

[upload]
    path = $PREFIX/upload
    writable = yes

[share]
    path = $PREFIX/share
    writeable = no
EOF


## start samba service
service smb restart

## test/verify
smbclient -L //localhost -U root%$PASSWORD
echo
tree $PREFIX
