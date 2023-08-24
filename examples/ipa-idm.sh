#!/usr/bin/env bash
#
. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

distro=${1:-9}
dnsdomain=lab.kissvm.net
domain=${dnsdomain}
realm=${domain^^}
ipaserv=ipa-server
nfsserv=nfs-server
ipaclnt=ipa-client
password=redhat123

### __prepare__ test env build
stdlog=$(trun vm create $distro --downloadonly |& tee /dev/tty)
imgf=$(sed -n '${s/^.* //;p}' <<<"$stdlog")

trun -tmux=$$-ipaserv vm create -n $ipaserv $distro --msize 4096 -p firewalld,bind-utils,expect,vim --nointeract -I=$imgf -f
trun -tmux=$$-ipaclnt vm create -n $ipaclnt $distro --msize 4096 -p bind-utils,vim,nfs-utils --nointeract -I=$imgf -f
trun                  vm create -n $nfsserv $distro --msize 4096 -p bind-utils,vim,nfs-utils --nointeract -I=$imgf -f
echo "{INFO} waiting all vm create process finished ..."
while ps axf|grep tmux.new.*-d.vm.creat[e]; do sleep 10; done

vm cpto $ipaserv /usr/bin/ipa-server-install.sh /usr/bin/kinit.sh /usr/bin/.
vm cpto $nfsserv /usr/bin/ipa-client-install.sh /usr/bin/{kinit.sh,make-nfs-server.sh} /usr/bin/.
vm cpto $ipaclnt /usr/bin/ipa-client-install.sh /usr/bin/kinit.sh /usr/bin/.
trun -tmux=$$-tmp1 vm exec -v $nfsserv -- ipa-client-install.sh
trun -tmux=$$-tmp2 vm exec -v $ipaclnt -- ipa-client-install.sh
vm exec -v $ipaserv -- ipa-server-install.sh
echo "{INFO} waiting all vm exec process finished ..."
while ps axf|grep tmux.new.*-d.vm.exe[c].*.ipa-.*-install.sh; do sleep 10; done

#-------------------------------------------------------------------------------
#configure ipa-server
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
_hostname=$(vm exec $ipaserv -- hostname)
_ipa_serv_addr=$(vm ifaddr $ipaserv)
vm exec -v $ipaserv -- "echo '$_ipa_serv_addr    $_hostname' >>/etc/hosts"
vm exec -v $ipaserv -- dig +short $_hostname A
vm exec -v $ipaserv -- dig +short -x $_ipa_serv_addr

#vm exec -v $ipaserv -- ipa-server-install --realm  ${realm} --ds-password $password --admin-password $password \
#	--mkhomedir --no-ntp --unattended
_zone=$(echo "$addr" | awk -F. '{ for (i=NF-1; i>0; i--) printf("%s.",$i) }')in-addr.arpa.
vm exec -v $ipaserv -- ipa-server-install --realm  ${realm} --ds-password $password --admin-password $password \
	--mkhomedir --no-ntp --setup-dns --no-forwarders --unattended --auto-reverse #--reverse-zone=$_zone
vm exec -v $ipaserv -- "grep ${_ipa_serv_addr%.*} /etc/resolv.conf || echo servername ${_ipa_serv_addr%.*}.1 >>/etc/resolv.conf"
vm exec -v $ipaserv -- cat /etc/resolv.conf
vm exec -v $ipaserv -- kinit.sh admin $password
vm exec -v $ipaserv -- ipa pwpolicy-mod --maxlife=365
passwd_expiration=$(date -dnow+8years +%F\ %TZ)
for User in li zhi cheng ben jeff steve; do
	vm exec -v $ipaserv -- expect -c "spawn ipa user-add $User --first $User --last jhts --password --shell=/bin/bash {--password-expiration=$passwd_expiration}
		expect {*:} {send \"$password\\n\"}
		expect {*:} {send \"$password\\n\"}
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
#configure nfsserver to join the realm
#Change host's DNS nameserver configuration to use the ipa/idm server.
vm exec -v $nfsserv -- "nmcli connection modify 'System eth0' ipv4.dns $_ipa_serv_addr; nmcli connection up 'System eth0'"
vm exec -v $nfsserv -- sed -i -e "/${_ipa_serv_addr%.*}/d" -e "s/^search.*/&\nnameserver ${_ipa_serv_addr}\nnameserver ${_ipa_serv_addr%.*}.1/" /etc/resolv.conf
vm exec -v $nfsserv -- cat /etc/resolv.conf

vm exec -v $nfsserv -- dig +short SRV _ldap._tcp.$dnsdomain
vm exec -v $nfsserv -- dig +short SRV _kerberos._tcp.$dnsdomain
vm exec -v $nfsserv -- ipa-client-install --domain=$domain --realm=${realm} --principal=admin --password=$password \
	--unattended --mkhomedir
vm exec -v $nfsserv -- kinit.sh admin $password
vm exec -v $nfsserv -- klist
vm exec -vx $ipaserv -- grep $nfsserv /var/log/krb5kdc.log
vm exec -v $ipaserv -- "journalctl -u named-pkcs11.service | grep ${nfsserv}.*updating"
vm exec -v $nfsserv -- 'ipa host-show $(hostname)'

#-------------------------------------------------------------------------------
#configure ipa-client to join the realm
#Change host's DNS nameserver configuration to use the ipa/idm server.
vm exec -v $ipaclnt -- "nmcli connection modify 'System eth0' ipv4.dns $_ipa_serv_addr; nmcli connection up 'System eth0'"
vm exec -v $ipaclnt -- cat /etc/resolv.conf
vm exec -v $ipaclnt -- sed -i -e "/${_ipa_serv_addr%.*}/d" -e "s/^search.*/&\nnameserver ${_ipa_serv_addr}\nnameserver ${_ipa_serv_addr%.*}.1/" /etc/resolv.conf
vm exec -v $ipaclnt -- cat /etc/resolv.conf

vm exec -v $ipaclnt -- dig +short SRV _ldap._tcp.$dnsdomain
vm exec -v $ipaclnt -- dig +short SRV _kerberos._tcp.$dnsdomain
vm exec -v $ipaclnt -- ipa-client-install --domain=$domain --realm=${realm} --principal=admin --password=$password \
	--unattended --mkhomedir #--server=$ipaserv.$domain
vm exec -v $ipaclnt -- kinit.sh admin $password
vm exec -v $ipaclnt -- klist

vm exec -v $ipaclnt -- 'ipa host-show $(hostname)'
vm exec -v $ipaclnt -- authselect list
vm exec -v $ipaclnt -- authselect show sssd
vm exec -v $ipaclnt -- authselect test -a sssd with-mkhomedir with-sudo

#-------------------------------------------------------------------------------
#nfs-server: configure krb5 nfs server
vm exec -v $nfsserv -- make-nfs-server.sh
vm exec -vx $nfsserv -- "chown :qe /nfsshare/qe; chown :devel /nfsshare/devel"
vm exec -vx $nfsserv -- chmod g+ws /nfsshare/qe /nfsshare/devel
vm exec -v $nfsserv -- ls -l /nfsshare

vm exec -v $nfsserv -- ipa service-add nfs/${nfsserv}.${domain}
vm exec -v $nfsserv -- ipa-getkeytab -s ${ipaserv}.${domain} -p nfs/${nfsserv}.${domain} -k /etc/krb5.keytab
vm exec -v $ipaserv -- kadmin.local list_principals
vm exec -v $nfsserv -- klist

#-------------------------------------------------------------------------------
#ipa-client: configure krb5 nfs client
vm exec -v $ipaclnt -- mkdir /mnt/nfsmp
vm exec -v $ipaclnt -- systemctl restart nfs-client.target gssproxy.service rpc-statd.service rpc-gssd.service
vm exec -v $ipaserv -- kadmin.local list_principals
vm exec -v $ipaclnt -- klist

### __main__ test start
#-------------------------------------------------------------------------------
#simple nfs mount/umount test
vm exec -vx $ipaclnt -- showmount -e ${nfsserv}
vm exec -vx $ipaclnt -- mount ${nfsserv}:/ /mnt/nfsmp
vm exec -vx $ipaclnt -- mount -t nfs4
vm exec -vx $ipaclnt -- umount -a -t nfs4

#-------------------------------------------------------------------------------
#simple krb5 nfs mount/umount test
vm exec -vx $ipaclnt -- mount -osec=krb5 ${nfsserv}.${domain}:/nfsshare/qe /mnt/nfsmp
vm exec -vx $ipaclnt -- mount -t nfs4
vm exec -vx $ipaclnt -- umount -a -t nfs4
