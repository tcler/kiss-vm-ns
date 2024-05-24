#!/bin/bash
#ref1: https://brianlinkletter.com/2019/02/build-a-network-emulator-using-libvirt/
#ref2: https://www.questioncomputer.com/ospf-on-ubuntu-22-04-and-rocky-linux-9-with-frr-8-4-free-range-routing/

[[ $1 != -* ]] && { distro="$1"; shift; }
distro=${distro:-9}

vm netcreate netname=net_user_r1 brname=br_user_r1 forward=no
vm netcreate netname=net_r1_r2 brname=br_r1_r2 forward=no
vm netcreate netname=net_r2_r3 brname=br_r2_r3 forward=no
vm netcreate netname=net_r1_r3 brname=br_r1_r3 forward=no
vm netcreate netname=net_r3_serv brname=br_r3_serv forward=no
vm del user server r{1..3} &>/dev/null

stdlog=$(vm create $distro --downloadonly "$@" |& tee /dev/tty)
imgf=$(sed -rn '${/^-[-rwx]{9}.? /{s/^.* //;p}}' <<<"$stdlog")
tmux new -s frr-user -d "vm create -n user ${distro} --net=default --net=net_user_r1,mac=02:00:aa:0a:01:02 -p traceroute,tcpdump,nmap -nointeract -I=$imgf $@"
tmux new -s frr-serv -d "vm create -n server ${distro} --net=default --net=net_r3_serv,mac=02:00:aa:0b:03:02 -p traceroute,tcpdump,nmap -nointeract -I=$imgf $@"
tmux new -s frr-r1 -d "vm create -n r1 ${distro} --net=default --net=net_user_r1,mac=02:00:aa:01:0a:02 --net=net_r1_r2,mac=02:00:aa:01:02:03 --net=net_r1_r3,mac=02:00:aa:01:03:04 -nointeract -I=$imgf $@"
tmux new -s frr-r2 -d "vm create -n r2 ${distro} --net=default --net=net_r2_r3,mac=02:00:aa:02:03:02 --net=net_r1_r2,mac=02:00:aa:02:01:03 -nointeract -I=$imgf $@"
vm create -n r3 ${distro} --net=default --net=net_r1_r3,mac=02:00:aa:03:01:02 --net=net_r2_r3,mac=02:00:aa:03:02:03 --net=net_r3_serv,mac=02:00:aa:03:0b:04 -nointeract -I=$imgf "$@"

for vm in user server r{1..3}; do
	vm port-available -w $vm
	vm cpto -v $vm /bin/ip2mac.sh /bin/frr-install.sh  /bin
	vm exec -v $vm -- "systemctl stop firewalld; systemctl disable firewalld"
done

vm exec -v user -- ip2mac.sh  02:00:aa:0a:01:02	 10.10.100.1/24
vm exec -v r1 -- ip2mac.sh  02:00:aa:01:0a:02 	10.10.100.2/24
vm exec -v r1 -- ip2mac.sh  02:00:aa:01:02:03 	10.10.12.1/24
vm exec -v r1 -- ip2mac.sh  02:00:aa:01:03:04 	10.10.13.1/24
vm exec -v r2 -- ip2mac.sh  02:00:aa:02:03:02 	10.10.23.1/24
vm exec -v r2 -- ip2mac.sh  02:00:aa:02:01:03 	10.10.12.2/24
vm exec -v r3 -- ip2mac.sh  02:00:aa:03:01:02 	10.10.13.2/24
vm exec -v r3 -- ip2mac.sh  02:00:aa:03:02:03 	10.10.23.2/24
vm exec -v r3 -- ip2mac.sh  02:00:aa:03:0b:04 	10.10.200.2/24
vm exec -v server -- ip2mac.sh  02:00:aa:0b:03:02 	10.10.200.1/24

for vm in r{1..3}; do
	vm exec -v $vm -- 'while ! rpm -q frr; do frr-install.sh; sleep 2; done'
	vm exec -v $vm -- sysctl -w net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1
	vm exec -v $vm -- sed -ri 's/(ospfd|zebra|staticd)=no/\1=yes/' /etc/frr/daemons
done

vm exec -v r1 -- 'cat >>/etc/frr/frr.conf <<EOF
frr defaults traditional
hostname r1
service integrated-vtysh-config
!
router ospf
 ospf router-id 1.1.1.1
 redistribute connected
 passive-interface eth1
 network 10.10.12.0/24 area 0
 network 10.10.13.0/24 area 0
 network 10.10.100.0/24 area 0
!
line vty
!
EOF
systemctl reload frr'

vm exec -v r2 -- 'cat >>/etc/frr/frr.conf <<EOF
frr defaults traditional
hostname r2
service integrated-vtysh-config
!
router ospf
 ospf router-id 2.2.2.2
 redistribute connected
 network 10.10.23.0/24 area 0
 network 10.10.12.0/24 area 0
!
line vty
!
EOF
systemctl reload frr'

vm exec -v r3 -- 'cat >>/etc/frr/frr.conf <<EOF
frr defaults traditional
hostname r3
service integrated-vtysh-config
!
router ospf
 ospf router-id 3.3.3.3
 redistribute connected
 passive-interface eth3
 network 10.10.13.0/24 area 0
 network 10.10.23.0/24 area 0
 network 10.10.200.0/24 area 0
!
line vty
!
EOF
systemctl reload frr'

#add route for user and server
vm exec -v user -- ip route add 10.10.0.0/16 via 10.10.100.2 dev eth1 metric 99
vm exec -v server -- ip route add 10.10.0.0/16 via 10.10.200.2 dev eth1 metric 99

#ping test
vm exec -v user -- ping -c 4  10.10.200.1
vm exec -v user -- traceroute 10.10.200.1

echo "{info} waiting ospf leart route to 10.10.200.0"
for ((i=0; i<32;i++)); do grep '^O>\* 10.10.200.0' < <(vm exec r1 -- vtysh -c 'show ip route') && break || sleep 2; done
vm exec -v r1 -- vtysh -c 'show ip route'
vm exec -v r2 -- vtysh -c 'show ip route'
vm exec -v r3 -- vtysh -c 'show ip route'

#ping test again
vm exec -v user -- traceroute 10.10.200.1
vm exec -vx user -- ping -c 4  10.10.200.1
