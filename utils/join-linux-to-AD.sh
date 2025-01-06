#!/bin/bash
# Integrate a RHEL/CentOS client into an AD DS Domain and config related roles for IDMAP or Secure NFS tests

LANG=C
P=${0##*/}

# Current Supported Extra Functions:
CONFIG_KRB5="no"   # Config secure NFS client
CLEANUP="no"       # Quit current AD Domain, clear entries in AD DS database

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

getDefaultNic() { ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]; exit}'; }
getDefaultIp4() {
	local nic=$1 nics=
	[[ -z "$nic" ]] && nics=$(getDefaultNic)
	for nic in $nics; do
		[[ -z "$(ip -d link show  dev $nic|sed -n 3p)" ]] && { break; }
	done
	local ipaddr=$(ip addr show $nic)
	local ret=$(echo "$ipaddr" |
		awk '/inet .* (global|host lo)/{match($0,"inet ([0-9.]+)",M); print M[1]}')
	echo "$ret"
}

Usage() {
cat <<END
Usage: $P -i <AD_DC_IP> -p <Password> --host-netbios <netbois-name> [-e <AES|DES>] [--config-krb]

        -h|--help                  # Print this help

        [Basic Function: Config current client as an AD DS Domain Member / Leave current Domain]
        -i|--addc-ip <IP address>  # Specify IP of a Windows AD DC for target AD DS Domain
        --addc-ip-ext <IP address> # another optional ip of Windows AD DC, used in /etc/hosts and /etc/resolv.conf
        -c|--cleanup               # Leave AD Domain and delete entry in AD database

        [Arguments for "AD Integration"]
        -p|--passwd <password>     # Specify password of Administrator@Domain instead of default
        -e|--enctypes <DES|AES>    # Choose enctypes for Kerberos TGT and TGS instead of default

        [Extra Functions: Config extra roles (IDMAP Client..) after integration]
	--host-netbios             # netbios name of the host. #used for join to Windows AD
        --config-krb               # Config current client as a Secure NFS client
	--rootdc                   # root DC ip
END
}
_at=`getopt -o hcp:i:e: \
	--long help \
	--long cleanup \
	--long passwd: \
	--long host-netbios: \
	--long addc-ip: \
	--long addc-ip-ext: \
	--long enctypes: \
	--long rootdc: \
	--long config-krb \
    -n '$P' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)      Usage; shift; exit 0;;
	-c|--cleanup)   CLEANUP="yes"; shift 1;;
	-p|--passwd)    AD_DS_SUPERPW="$2"; shift 2;;
	--host-netbios) HOST_NETBIOS=$2; shift 2;;
	-e|--enctypes)  krbEnc="$2"; shift 2;;
	--rootdc)       ROOT_DC="$2"; shift 2;;
	--config-krb*)  CONFIG_KRB5="yes"; shift 1;;
	-i|--addc-ip)   AD_DC_IP="$2"; shift 2;;
	--addc-ip-ext)  [[ "$2" != 169.254.* ]] && AD_DC_IP_EXT="$2"; shift 2;;
	--) shift; break;;
	esac
done

[ -z "$AD_DC_IP" ] && {
	errecho "{WARN} Please specify IP of target AD Domain's Domain Controller/DC: --addc-ip="
	Usage;
	exit 1;
}

[ -z "$AD_DS_SUPERPW" ] && {
	errecho "{WARN} Please specify admin password of target AD Domain's Domain Controller/DC: --passwd="
	Usage;
	exit 1;
}

# length of NetBIOS name should be less than or equal to 15
HOST_NETBIOS=${HOST_NETBIOS:-$HOSTNAME}
[[ ${#HOST_NETBIOS} -gt 15 ]] && {
	errecho "[ERROR] the length of hostname($HOST_NETBIOS) should be less than 15, see: --host-netbios="
	exit 1
}

#
# PART: [Dependency] Specify all dependencies during integration related jobs
#

# Specify packages for "Windows AD Integration (SSSD ad_provider)"
pkgs="adcli krb5-workstation sssd pam_krb5
    samba samba-winbind samba-common samba-client
    samba-winbind samba-winbind-clients
    samba-winbind-krb5-locator"

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
  example.com = EXAMPLE.COM
"

#
# PART: [Preparing] Prepare AD DS/DC Information
#

if [ "$CLEANUP" == "yes" ]; then
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
AD_DC_NETBIOS=$(echo $AD_DC_FQDN | awk -F . '{print $1}' | tr a-z A-Z);

# Specify NetBIOS name of current client in target AD Domain
MY_FQDN=${HOST_NETBIOS,,}.${AD_DS_NAME,,}
MY_NETBIOS=${MY_FQDN%%.*}

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

infoecho "{INFO} Clean old principals..."
kdestroy -A
\rm -f /etc/krb5.keytab
\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0

infoecho "{INFO} Change DNS Server to AD Domain DNS..."
run 'echo -e "[main]\ndns=none" >/etc/NetworkManager/NetworkManager.conf'
run 'systemctl restart NetworkManager'
run 'echo -e "make_resolv_conf(){\n    :\n}" >/etc/dhclient-enter-hooks'
if grep -q 127.0.0.53 $RESOLV_CONF; then
	resolvedConf=/etc/systemd/resolved.conf
	if grep -q ^DNS= $resolvedConf; then
		sed -i "/^DNS=/s/$/$ROOT_DC ${AD_DC_IP_EXT:-$AD_DC_IP}/" $resolvedConf
	else
		echo "DNS=$ROOT_DC ${AD_DC_IP_EXT:-$AD_DC_IP}" >>$resolvedConf
	fi
	systemctl restart systemd-resolved
else
	mv $RESOLV_CONF ${RESOLV_CONF}.orig
	{
		grep -E -i "^search.* ${AD_DS_NAME,,}( |$)" ${RESOLV_CONF}.orig ||
			sed -n -e "/^search/{s//& ${AD_DS_NAME,,}/; p}" ${RESOLV_CONF}.orig
		for nsaddr in $ROOT_DC ${AD_DC_IP_EXT:-$AD_DC_IP}; do
			grep -E -q "^nameserver $nsaddr" ${RESOLV_CONF}.orig ||
				echo "nameserver $nsaddr   #windows-ad"
		done
		grep -E ^nameserver ${RESOLV_CONF}.orig | grep -v '#windows-ad'
	} >$RESOLV_CONF
	run "cat $RESOLV_CONF"
fi

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
realm = $AD_DS_NAME
netbios name = $HOST_NETBIOS

security = ads
#password server = $AD_DC_FQDN  #conflict with security=ads

#to create entry using principal 'computer$@REALM'
sync machine password to keytab = /etc/krb5.keytab:account_name:machine_password

#idmap config is necessary to avoid testparm ERROR
#see also:
#- https://www.linuxquestions.org/questions/linux-software-2/samba-4-10-16-error-invalid-idmap-range-for-domain-%2A-on-centos-linux-7-core-4175730670/#post6467357
#- man smb.conf(5)
#idmap config CORP : backend  = ad
#idmap config CORP : range = 1000-999999
idmap config * : backend = tdb
idmap config * : range = 1000000-1999999
min domain uid = 1000
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
krb5CCACHE=$(LANG=C klist | sed -n '/Ticket.cache: /{s///;p}')
netKrb5Opt=--use-krb5-ccache=${krb5CCACHE#*:}

man net | grep -q .-k.--kerberos && netKrb5Opt=-k   #for rhel-7
# Join host to an Active Directory (AD), and update the DNS
for ((i=0; i<16; i++)); do
	run "net ads join $netKrb5Opt dnshostname=${MY_FQDN}"
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

if man net | grep -q .-k.--kerberos; then   #for rhel-7
	netKrb5Opt=
	run "net ads dns gethostbyname $AD_DC_FQDN $HOST_NETBIOS $netKrb5Opt"
else
	run "net ads dns async ${MY_FQDN} $netKrb5Opt"
fi
if [ $? -ne 0 ]; then
	errecho "Failed to find dns entry from AD"
	run "net ads dns register ${MY_FQDN} $netKrb5Opt"
	if [ $? -ne 0 ]; then
		errecho "Failed to add host dns entry to AD"
		#exit 1;
	else
		run "net ads dns async ${MY_FQDN} $netKrb5Opt"
	fi
fi

infoecho "SUCCESS - AD Integration to Domain ${AD_DS_NAME} successfully."

infoecho "start nfs client services ..."
systemctl restart nfs-client.target gssproxy.service rpc-statd.service rpc-gssd.service

#nfs krb5 mount requires hostname == netbios_name
infoecho "hostname $HOST_NETBIOS ..."
hostname $HOST_NETBIOS
hostname ${MY_FQDN}
hostnamectl hostname ${MY_FQDN}

#
# PART: [Extra Functions] Config current client as a Secure NFS client
#

if [ "$CONFIG_KRB5" == "yes" ]; then
	sed -ri '/^# ?verbosity=.*$/{s//verbosity=3/}' /etc/nfs.conf

	infoecho "krb 1. Use 'net ads' to add related service principals..."
	# Only need "-U Administrator%${AD_DS_SUPERPW}" when ticket
	# "Administrator@${AD_DS_NAME}" expires, otherwise just skip
	run "net ads setspn list $netKrb5Opt"

	run "net ads setspn add host/$MY_FQDN $netKrb5Opt"
	run "net ads setspn add host/$MY_NETBIOS $netKrb5Opt"

	run "net ads setspn add root/$MY_FQDN $netKrb5Opt"
	run "net ads setspn add root/$MY_NETBIOS $netKrb5Opt"

	run "net ads setspn add nfs/$MY_FQDN $netKrb5Opt"
	run "net ads setspn add nfs/$MY_NETBIOS $netKrb5Opt"

	run "net ads keytab create $netKrb5Opt"
	run "net ads setspn list $netKrb5Opt"

	run "klist -e -k -t /etc/krb5.keytab"
	if [ $? -ne 0 ]; then
		errecho "Configure Secure NFS Client Failed, cannot read keytab file."
	fi

	infoecho "Configure Secure NFS Client complete."
fi

