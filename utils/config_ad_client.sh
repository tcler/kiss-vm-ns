#!/bin/bash
# Integrate a RHEL/CentOS client into an AD DS Domain and config related roles for IDMAP or Secure NFS tests

LANG=C
P=${0##*/}

Usage() {
cat <<END
Usage: config_ad_client.sh -i <AD_DC_IP> -p <Password> --host-netbios <netbois_name> [-e <AES|DES>] [--config_idmap|--config_krb]

        -h|--help                  # Print this help

        [Basic Function: Config current client as an AD DS Domain Member / Leave current Domain]
        -i|--addc_ip <IP address>  # Specify IP of a Windows AD DC for target AD DS Domain
        --addc_ip_ext <IP address> # another optional ip of Windows AD DC, used in /etc/hosts and /etc/resolv.conf
        -c|--cleanup               # Leave AD Domain and delete entry in AD database

        [Arguments for "AD Integration"]
        -e|--enctypes <DES|AES>    # Choose enctypes for Kerberos TGT and TGS instead of default
        -p|--passwd <password>     # Specify password of Administrator@Domain instead of default

        [Extra Functions: Config extra roles (IDMAP Client..) after integration]
        --config_idmap             # Config current client as an NFSv4 IDMAP client
        --config_krb               # Config current client as a Secure NFS client
	--rootdc                   # root DC ip
	--host-netbios             # netbios name of the host. #used for join to Windows AD
END
}

infoecho() { echo -e "\n<${P}>""\E[1;34m" "$@" "\E[0m"; }
errecho()  { echo -e "\n<${P}>""\E[31m" "$@" "\E[0m"; }
run() {
	local cmdline=$1
	local expect_ret=${2:-0}
	local comment=${3:-$cmdline}
	local ret=0

	echo "[$(date +%T) $USER@ ${PWD%%*/}]# $cmdline"
	eval $cmdline
	ret=$?
	[[ $expect_ret != - && $expect_ret != $ret ]] && {
		echo "$comment" FAIL
		let retcode++
	}

	return $ret
}

getDefaultNic() {
	ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'
}
getDefaultIp4() {
	local nic=$(getDefaultNic)
	ip addr show $nic | awk '/inet .* global dynamic/{match($0,"inet ([0-9.]+)",M); print M[1]}'
}

[ $# -eq 0 ] && {
       Usage;
       exit 1;
}

# Current Supported Extra Functions:
config_krb="no"    # Config secure NFS client
config_idmap="no"  # Config NFSv4 idmap client

cleanup="no"       # Quit current AD Domain, clear entries in AD DS database

while [ -n "$1" ]; do
	case "$1" in
	--config_idmap) config_idmap="yes";shift 1;;
	--config_krb) config_krb="yes";shift 1;;
	-c|--cleanup) cleanup="yes";shift 1;;
	-e|--enctypes) krbEnc="$2";shift 2;;
	-i|--addc_ip) AD_DC_IP="$2";shift 2;;
	--addc_ip_ext) AD_DC_IP_EXT="$2";shift 2;;
	--rootdc) ROOT_DC="$2";shift 2;;
	-p|--passwd)  AD_DS_SUPERPW="$2";shift 2;;
	-h|--help)    Usage;exit 0;;
	--host-netbios) HOST_NETBIOS=$2; shift 2;;
	*) break;;
	esac
done

#
# PART: [Dependency] Specify all dependencies during integration related jobs
#

# length of NetBIOS name should be less than or equal to 15
HOST_NETBIOS=${HOST_NETBIOS:-$HOSTNAME}
[[ ${#HOST_NETBIOS} -gt 15 ]] && {
	errecho "[ERROR] the length of hostname($HOST_NETBIOS) should be less than 15, try following commands"
	exit 1
}

# Specify NetBIOS name of current client in target AD Domain
MY_FQDN=${HOST_NETBIOS^^}
MY_NETBIOS=${MY_FQDN%%.*}

# Specify packages for "Windows AD Integration (SSSD ad_provider)"
pkgs="adcli krb5-workstation sssd pam_krb5
    samba samba-winbind samba-common samba-client
    samba-winbind samba-winbind-clients
    samba-winbind-krb5-locator"

# Specify extra packages for "NFSv4 IDMAP"
idmap_pkgs="nfs-utils libnfsidmap nfs-utils-lib
    authconfig oddjob-mkhomedir"

# Specify target AD Domain and its Domain Controller/DC information
AD_DS_NAME=""
AD_DS_NETBIOS=""
AD_DC_FQDN=""
AD_DC_NETBIOS=""

# Specify KDC information for Kerberos related procedures
REALM=""
krbKDC=""

# Specify related configuration files
KRB_CONF=/etc/krb5.conf
SMB_CONF=/etc/samba/smb.conf
HOSTS_CONF=/etc/hosts
RESOLV_CONF=/etc/resolv.conf
SSSD_CONF=/etc/sssd/sssd.conf
IDMAP_CONF=/etc/idmapd.conf

# Specify Standard KRB5 Configuration File
krbConfTemp="[logging]
  default = FILE:/var/log/krb5libs.log

[libdefaults]
  default_realm = EXAMPLE.COM
  dns_lookup_realm = true
  dns_lookup_kdc = true
  ticket_lifetime = 24h
  renew_lifetime = 7d
  forwardable = true
  rdns = false

[realms]
  EXAMPLE.COM = {
    kdc = kerberos.example.com
    admin_server = kerberos.example.com
    default_domain = kerberos.example.com
  }

[domain_realm]
  .example.com = .EXAMPLE.COM
  example.com = EXAMPLE.COM"

# Specify Standard SSSD ad_provider Configuration File
sssd_ad_providerConfTemp="[nss]
  fallback_homedir = /home/%u
  shell_fallback = /bin/sh
  allowed_shells = /bin/sh,/bin/rbash,/bin/bash
  vetoed_shells = /bin/ksh

[sssd]
  config_file_version = 2
  domains = example.com
  services = nss, pam, pac

[domain/example.com]
  id_provider = ad
  auth_provider = ad
  chpass_provider = ad
  access_provider = ad
  cache_credentials = true
  override_homedir = /home/%d/%u
  default_shell = /bin/bash
  use_fully_qualified_names = True"


#
# PART: [Preparing] Prepare AD DS/DC Information
#

if [ "$cleanup" == "yes" ]; then
	echo "{Info} Try to leave the current AD DS Domain"
	run "net ads leave -U Administrator%${AD_DS_SUPERPW}"
	if [ $? -eq 0 ]; then
		infoecho "Leave AD DS Domain by 'net ads' Success."
		exit 0;
	else
		errecho "Leave AD DS Domain by 'net ads' Failed."
		exit 1;
	fi
fi

[ -z "$AD_DC_IP" ] && {
	errecho "{WARN} Please specify IP of target AD Domain's Domain Controller/DC"
	Usage;
	exit 1;
}

[ -z "$AD_DS_SUPERPW" ] && {
	errecho "{WARN} Please specify admin password of target AD Domain's Domain Controller/DC"
	Usage;
	exit 1;
}

infoecho "Check connections with AD DC by IP..."
run "ping -c 2 $AD_DC_IP"
test $? -eq 0 || {
	errecho "{WARN} Can not connect to AD DC via IP: '${AD_DC_IP}'"
	exit 1;
}

infoecho "Obtain information of the AD Domain and its Domain Controller..."
rpm -q adcli &>/dev/null || yum -y install adcli &>/dev/null

# Get AD DS/DC information by adcli
run "adcli info --domain-controller=${AD_DC_IP}"

AD_DC_FQDN=$(adcli info --domain-controller=${AD_DC_IP}    | awk '/domain-controller =/{print $NF}' | tr a-z A-Z);
AD_DS_NAME=$(adcli info --domain-controller=${AD_DC_IP}    | awk '/domain-name =/{print $NF}'       | tr a-z A-Z);
AD_DS_NETBIOS=$(adcli info --domain-controller=${AD_DC_IP} | awk '/domain-short =/{print $NF}'      | tr a-z A-Z);
AD_DC_NETBIOS=$(echo $AD_DC_FQDN | awk -F . '{print $1}'                  | tr a-z A-Z);

echo -e "\n{Info} Logging the variables:"
echo "AD_DC_FQDN is $AD_DC_FQDN"
echo "AD_DS_NAME is $AD_DS_NAME"
echo "AD_DS_NETBIOS is $AD_DS_NETBIOS"
echo "AD_DC_NETBIOS is $AD_DC_NETBIOS"
if [ $((${#AD_DS_NAME}*${#AD_DS_NETBIOS}*${#AD_DC_FQDN})) -eq 0 ]; then
	echo "{WARN} Can not get sufficient AD Domain information, please check AD DC SRV Records'";
	exit 1
else
	echo "{Info} Will start to integrate into AD Domain: $AD_DS_NAME";
fi

#
# PART: [Basic Function] Config current client as an AD DS Domain Member
#

infoecho "{INFO} Make sure necessary packages are installed..."
rpm -q $pkgs &>/dev/null || yum --setopt=strict=0 -y install $pkgs &>/dev/null

if [ "$config_idmap" == "yes" ]; then
	rpm -q $idmap_pkgs &>/dev/null || yum -y install $idmap_pkgs &>/dev/null
fi

infoecho "{INFO} Clean old principals..."
kdestroy -A
\rm -f /etc/krb5.keytab
\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0

infoecho "{INFO} Change DNS Server to AD Domain DNS..."
run 'echo -e "[main]\ndns=none" >/etc/NetworkManager/NetworkManager.conf'
run 'systemctl restart NetworkManager'
run 'echo -e "make_resolv_conf(){\n    :\n}" >/etc/dhclient-enter-hooks'
mv $RESOLV_CONF ${RESOLV_CONF}.orig
{
	egrep -i "^search.* ${AD_DS_NAME,,}( |$)" ${RESOLV_CONF}.orig ||
		sed -n -e "/^search/{s//& ${AD_DS_NAME,,}/; p}" ${RESOLV_CONF}.orig
	for nsaddr in $ROOT_DC ${AD_DC_IP_EXT:-$AD_DC_IP}; do
		egrep -q "^nameserver $nsaddr" ${RESOLV_CONF}.orig ||
			echo "nameserver $nsaddr   #windows-ad"
	done
	egrep ^nameserver ${RESOLV_CONF}.orig | grep -v '#windows-ad'
} >$RESOLV_CONF

run "cat $RESOLV_CONF"

infoecho "{INFO} Close the firewall..."
[ -f /etc/init.d/iptables ] && service iptables stop
which systemctl &>/dev/null && {
	firewall-cmd --permanent --add-service=kerberos
	firewall-cmd --reload
}

infoecho "{INFO} Fix ADDC IP and FQDN mappings..."
sed -i -e "/$AD_DC_FQDN/d" -e "/${HOST_NETBIOS}/d" $HOSTS_CONF
echo "${AD_DC_IP_EXT:-$AD_DC_IP} $AD_DC_FQDN $AD_DC_NETBIOS" >> $HOSTS_CONF
echo "$(getDefaultIp4) ${HOST_NETBIOS} ${HOST_NETBIOS}.${AD_DS_NAME,,}" >> $HOSTS_CONF
run "cat $HOSTS_CONF"

infoecho "{INFO} Configure '$KRB_CONF', edit the realm name..."
echo "$krbConfTemp" >$KRB_CONF
REALM="$AD_DS_NAME"
krbKDC="$AD_DC_FQDN"
sed -r -i -e 's;^#+;;' -e "/EXAMPLE.COM/{s//$REALM/g}" -e "/kerberos.example.com/{s//$krbKDC/g}"   $KRB_CONF
sed -r -i -e "/ (\.)?example.com/{s// \1${krbKDC#*.}/g}"                                           $KRB_CONF
sed -r -i -e "/dns_lookup_realm/{s/false/true/g}" -e "/dns_lookup_kdc/{s/false/true/g}"            $KRB_CONF

if [ "$krbEnc" == "DES" ]; then
	sed -i -e '/libdefaults/{s/$/\n  default_tgs_enctypes = des3-cbc-sha1 arcfour-hmac-md5 rc4-hmac des-cbc-crc des-cbc-md5/}'  $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  default_tkt_enctypes = des3-cbc-sha1 arcfour-hmac-md5 rc4-hmac des-cbc-crc des-cbc-md5/}'  $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  permitted_enctypes = des3-cbc-sha1 arcfour-hmac-md5 rc4-hmac des-cbc-crc des-cbc-md5/}'    $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  allow_weak_crypto = true/}' $KRB_CONF
	echo "{Info} Kerberos will choose from DES enctypes to select one for TGT and TGS procedures"
elif [ "$krbEnc" == "AES" ]; then
	sed -i -e '/libdefaults/{s/$/\n  default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac/}'  $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac/}'  $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac/}'    $KRB_CONF
	sed -i -e '/libdefaults/{s/$/\n  allow_weak_crypto = true/}' $KRB_CONF
	echo "{Info} Kerberos will choose from AES enctypes to select one for TGT and TGS procedures"
else
	echo "{Info} Kerberos will choose a valid enctype from default enctypes (order: AES 256 > AES 128 > DES) for TGT and TGS procedures"
fi
run "cat $KRB_CONF"

infoecho "{INFO} Configure $SMB_CONF, edit target Windows Domain information..."
cat > $SMB_CONF <<EOFL
[global]
workgroup = $AD_DS_NETBIOS
client signing = yes
client use spnego = yes
kerberos method = secrets and keytab
password server = $AD_DC_FQDN
realm = $AD_DS_NAME
netbios name = $HOST_NETBIOS
security = ads
EOFL
run "cat $SMB_CONF"

infoecho "{INFO} configure domain and nobody user in idmap.conf"
sed -i "s/.*Domain =.*/Domain = ${AD_DS_NAME}/" $IDMAP_CONF
sed -i '/Nobody-User =/s/^#//' $IDMAP_CONF
sed -i '/Nobody-Group =/s/^#//' $IDMAP_CONF

#add dns entry for client host netbios
sshOpts="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
expect -c "spawn ssh $sshOpts Administrator@${AD_DC_IP:-$AD_DC_IP_EXT} powershell -Command {Add-DnsServerResourceRecordA -Name $HOST_NETBIOS -ZoneName $AD_DS_NAME -AllowUpdateAny -IPv4Address $(getDefaultIp4)}
expect {password:} { send \"${AD_DS_SUPERPW}\\r\" }
expect eof
"

infoecho "{INFO} Fetch TGT first & Join AD Realm..."
run "KRB5_TRACE=/dev/stdout kinit -V Administrator@${AD_DS_NAME} <<< ${AD_DS_SUPERPW}"
if [ $? -ne 0 ]; then
	errecho "AD Integration Failed, cannot get TGT principal of Administrator@${AD_DS_NAME} during kinit"
	exit 1;
fi
run "kinit Administrator <<< ${AD_DS_SUPERPW}"
run "klist"

# Join host to an Active Directory (AD), and update the DNS
for ((i=0; i<16; i++)); do
	run "net ads join --kerberos"
	join_res=$?
	if [ $join_res -eq 0 ]; then
		break
	else
		sleep 8
	fi
done
if [ $join_res -ne 0 ]; then
	errecho "AD Integration Failed, cannot join AD Domain by 'net ads join'"
	exit 1
fi

run "net ads dns gethostbyname $AD_DC_FQDN $HOST_NETBIOS"
if [ $? -ne 0 ]; then
	errecho "Failed to find dns entry from AD"
	run "net ads dns register $HOST_NETBIOS"
	if [ $? -ne 0 ]; then
		errecho "Failed to add host dns entry to AD"
		#exit 1;
	else
		run "net ads dns gethostbyname $AD_DC_FQDN $HOST_NETBIOS"
	fi
fi

infoecho "SUCCESS - AD Integration to Domain ${AD_DS_NAME} successfully."

infoecho "start rpc-gssd service ..."
systemctl start rpc-gssd

#nfs krb5 mount requires hostname == netbios_name
infoecho "hostname $HOST_NETBIOS ..."
hostname $HOST_NETBIOS

#
# PART: [Extra Functions] Config current client as an NFSv4 IDMAP client
#

if [ "$config_idmap" == "yes" ]; then
	infoecho "IDMAP 1. Enable sssd ad_provider to work as a Name Service..."
	authconfig --update --enablesssd --enablesssdauth --enablemkhomedir
	echo "$sssd_ad_providerConfTemp" >$SSSD_CONF
	sed -r -i -e "/example.com/{s//$AD_DS_NAME/g}"    $SSSD_CONF
	chmod 600 $SSSD_CONF
	restorecon $SSSD_CONF
	run "cat $SSSD_CONF"

	if ! service sssd restart; then
		echo "SSSD service cannot load, please check $SSSD_CONF"
		exit 1;
	fi

	infoecho "IDMAP 2. Start NFSv4 idmapping and configure rpc.idmapd..."
	modprobe nfsd; modprobe nfs
	echo "N"> /sys/module/nfs/parameters/nfs4_disable_idmapping
	echo "N"> /sys/module/nfsd/parameters/nfs4_disable_idmapping
	which systemctl &>/dev/null && systemctl restart nfs-idmapd || service rpcidmapd restart

	infoecho "IDMAP 3. Check sssd status by getent of common users..."
	run "getent passwd Administrator@${AD_DS_NAME}"
	if [ $? -ne 0 ]; then
		errecho "Configure NFSv4 IDMAP Client Failed, query user information failed for Administrator@${AD_DS_NAME}"
		exit 1;
	fi
	run "getent passwd krbtgt@${AD_DS_NAME}"
	if [ $? -ne 0 ]; then
		errecho "Configure NFSv4 IDMAP Client Failed, query user information failed for krbtgt@${AD_DS_NAME}"
		exit 1;
	fi
	run "getent group "Domain Admins"@${AD_DS_NAME}"
	if [ $? -ne 0 ]; then
		errecho "Configure NFSv4 IDMAP Client Failed, query group information failed for Domain Admins@${AD_DS_NAME}"
		exit 1;
	fi
	run "getent group "Domain Users"@${AD_DS_NAME}"
	if [ $? -ne 0 ]; then
		errecho "Configure NFSv4 IDMAP Client Failed, query group information failed for Domain Users@${AD_DS_NAME}"
		exit 1;
	fi

	infoecho "SSSD based NFSv4 IDMAP client configuration complete."
fi

#
# PART: [Extra Functions] Config current client as a Secure NFS client
#

if [ "$config_krb" == "yes" ]; then
	infoecho "krb 1. Use 'net ads' to add related service principals..."

	# Only need "-U Administrator%${AD_DS_SUPERPW}" when ticket
	# "Administrator@${AD_DS_NAME}" expires, otherwise just skip
	run "net ads setspn list"

	net ads setspn list | grep -q HOST || {
		run "net ads setspn add HOST/$MY_FQDN"
		run "net ads setspn add HOST/$MY_NETBIOS"
	}
	run "net ads keytab add HOST"
	if [ $? -ne 0 ]; then
		errecho "Configure Secure NFS Client Failed, cannot add principal: HOST"
		exit 1;
	fi

	net ads setspn list | grep -q ROOT || {
		run "net ads setspn add ROOT/$MY_FQDN"
		run "net ads setspn add ROOT/$MY_NETBIOS"
	}
	run "net ads keytab add ROOT"
	if [ $? -ne 0 ]; then
		errecho "Configure Secure NFS Client Failed, cannot add principal: ROOT"
		exit 1;
	fi

	net ads setspn list | grep -q NFS || {
		run "net ads setspn add NFS/$MY_FQDN"
		run "net ads setspn add NFS/$MY_NETBIOS"
	}
	run "net ads keytab add NFS"
	if [ $? -ne 0 ]; then
		errecho "Configure Secure NFS Client Failed, cannot add principal: NFS"
		exit 1;
	fi
	run "net ads setspn list"

	run "klist -e -k -t /etc/krb5.keytab"
	if [ $? -ne 0 ]; then
		errecho "Configure Secure NFS Client Failed, cannot read keytab file."
	fi

	infoecho "Configure Secure NFS Client complete."
fi


