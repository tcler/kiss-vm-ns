#!/bin/bash
#
. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

distro=${1:-CentOS-9-stream}
dnsdomain=lab.kissvm.net
ipaserv=ipa-server
ipaclnt=ipa-client
password=redhat123
vm create -n $ipaserv $distro --msize 4096 -p "firewalld bind-utils expect vim" --nointeract --saveimage -f
vm cpto $ipaserv /usr/bin/ipa-server-install.sh /usr/bin/kinit.sh /usr/bin/.
vm exec -v $ipaserv -- systemctl start firewalld
vm exec -v $ipaserv -- systemctl enable firewalld
vm exec -v $ipaserv -- firewall-cmd --add-service=freeipa-ldap
vm exec -v $ipaserv -- firewall-cmd --add-service=freeipa-ldaps
vm exec -v $ipaserv -- firewall-cmd --add-service=http
vm exec -v $ipaserv -- firewall-cmd --add-service=https
vm exec -v $ipaserv -- firewall-cmd --add-service=kerberos
vm exec -v $ipaserv -- firewall-cmd --add-service=dns
vm exec -v $ipaserv -- firewall-cmd --add-service=freeipa-ldap --permanent
vm exec -v $ipaserv -- firewall-cmd --add-service=freeipa-ldaps --permanent
vm exec -v $ipaserv -- firewall-cmd --add-service=http --permanent
vm exec -v $ipaserv -- firewall-cmd --add-service=https --permanent
vm exec -v $ipaserv -- firewall-cmd --add-service=kerberos --permanent
vm exec -v $ipaserv -- firewall-cmd --add-service=dns --permanent
hostname=$(vm exec $ipaserv -- hostname)
servaddr=$(vm ifaddr $ipaserv)
vm exec -v $ipaserv -- "echo '$servaddr    $hostname' >>/etc/hosts"
vm exec -v $ipaserv -- dig +short $hostname A
vm exec -v $ipaserv -- dig +short -x $servaddr

vm exec -v $ipaserv -- ipa-server-install.sh
_zone=$(echo "$addr" | awk -F. '{ for (i=NF-1; i>0; i--) printf("%s.",$i) }')in-addr.arpa.
vm exec -v $ipaserv -- ipa-server-install --realm  ${dnsdomain^^} --ds-password $password --admin-password $password \
	--mkhomedir --no-ntp --setup-dns --no-forwarders --unattended --auto-reverse #--reverse-zone=$_zone
vm exec -v $ipaserv -- "grep ${servaddr%.*} /etc/resolv.conf || echo servername ${servaddr%.*}.1 >>/etc/resolv.conf"
vm exec -v $ipaserv -- cat /etc/resolv.conf
vm exec -v $ipaserv -- kinit.sh admin $password
vm exec -v $ipaserv -- ipa pwpolicy-mod --maxlife=365
passwd_expiration=$(date -dnow+8years +%F\ %TZ)
for User in li zhi cheng ben jeff steve; do
	vm exec -v $ipaserv -- expect -c "spawn ipa user-add $User --first $User --last jhts --password --shell=/bin/bash {--password-expiration=$passwd_expiration}
		expect {*:} {send \"$password\\r\"}
		expect {*:} {send \"$password\\r\"}
		expect eof"
done
vm exec -v $ipaserv -- ipa user-find

for Group in qe devel; do
	vm exec -v $ipaserv -- "ipa group-add $Group --desc '$Group group'"
done
vm exec -v $ipaserv -- ipa group-add-member qe --users={li,zhi,cheng}
vm exec -v $ipaserv -- ipa group-add-member devel --users={ben,jeff,steve}
vm exec -v $ipaserv -- sssctl domain-list
vm exec -v $ipaserv -- sssctl user-show admin

#-------------------------------------------------------------------------------
#create new VM ipa-client to join the realm
vm create -n $ipaclnt $distro --msize 4096 -p "bind-utils vim nfs-utils" --nointeract --saveimage -f
vm cpto $ipaclnt /usr/bin/ipa-client-install.sh /usr/bin/kinit.sh /usr/bin/.
vm exec -v $ipaclnt -- ipa-client-install.sh

#Change client's DNS nameserver configuration to use the ipa/idm server.
vm exec -v $ipaclnt -- "nmcli connection modify 'System eth0' ipv4.dns $servaddr; nmcli connection up 'System eth0'"
vm exec -v $ipaclnt -- cat /etc/resolv.conf
vm exec -v $ipaclnt -- sed -i -e "/${servaddr%.*}/d" -e "s/^search.*/&\nnameserver ${servaddr}\nnameserver ${servaddr%.*}.1/" /etc/resolv.conf
vm exec -v $ipaclnt -- cat /etc/resolv.conf

vm exec -v $ipaclnt -- dig +short SRV _ldap._tcp.$dnsdomain
vm exec -v $ipaclnt -- dig +short SRV _kerberos._tcp.$dnsdomain
vm exec -v $ipaclnt -- ipa-client-install --domain=$dnsdomain --realm=${dnsdomain^^} --principal=admin --password=$password \
	--unattended --mkhomedir #--server=$ipaserv.$dnsdomain
vm exec -v $ipaclnt -- kinit.sh admin $password
vm exec -v $ipaclnt -- klist
vm exec -v $ipaserv -- grep $ipaclnt /var/log/krb5kdc.log
vm exec -v $ipaserv -- "journalctl -u named-pkcs11.service | grep ${ipaclnt}.*updating"

vm exec -v $ipaclnt -- 'ipa host-show $(hostname)'
vm exec -v $ipaclnt -- authselect list
vm exec -v $ipaclnt -- authselect show sssd
vm exec -v $ipaclnt -- authselect test -a sssd with-mkhomedir with-sudo

vm exec -v $ipaclnt -- mkdir /mnt/nfsmp

#-------------------------------------------------------------------------------
#create new VM ipa-nfsserver to join the realm
nfsserv=nfs-server
vm create -n $nfsserv $distro --msize 4096 -p "bind-utils vim nfs-utils" --nointeract --saveimage -f
vm cpto $nfsserv /usr/bin/ipa-client-install.sh /usr/bin/kinit.sh /usr/bin/.
vm exec -v $nfsserv -- ipa-client-install.sh
vm exec -v $nfsserv -- "nmcli connection modify 'System eth0' ipv4.dns $servaddr; nmcli connection up 'System eth0'"
vm exec -v $nfsserv -- sed -i -e "/${servaddr%.*}/d" -e "s/^search.*/&\nnameserver ${servaddr}\nnameserver ${servaddr%.*}.1/" /etc/resolv.conf
vm exec -v $nfsserv -- ipa-client-install --domain=$dnsdomain --realm=${dnsdomain^^} --principal=admin --password=$password \
	--unattended --mkhomedir
vm exec -v $nfsserv -- kinit.sh admin $password
vm exec -v $nfsserv -- 'ipa host-show $(hostname)'
vm exec -v $nfsserv -- mkdir -p /expdir/qe /expdir/devel
vm exec -v $nfsserv -- "chown :qe /expdir/qe; chown :devel /expdir/devel"
vm exec -v $nfsserv -- chmod g+ws /expdir/qe /expdir/devel
vm exec -v $nfsserv -- ls -l /expdir
vm exec -v $nfsserv -- "echo '/expdir *(rw,no_root_squash)' >/etc/exports"
vm exec -v $nfsserv -- systemctl start nfs-server
vm exec -v $nfsserv -- kadmin.local list_principals

#-------------------------------------------------------------------------------
vm exec -v $ipaclnt -- showmount -e ${nfsserv}
vm exec -v $ipaclnt -- mount ${nfsserv}:/ /mnt/nfsmp
vm exec -v $ipaclnt -- mount -t nfs4
