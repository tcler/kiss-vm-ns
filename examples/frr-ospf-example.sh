#!/bin/bash
#ref1: https://brianlinkletter.com/2019/02/build-a-network-emulator-using-libvirt/
#ref2: https://www.questioncomputer.com/ospf-on-ubuntu-22-04-and-rocky-linux-9-with-frr-8-4-free-range-routing/

[[ $1 != -* ]] && { distro="$1"; shift; }
distro=${distro:-9}

#mac-address and static-ip
addr_user_r1=(02:00:aa:0a:01:02 10.10.100.1/24)
addr_serv_r3=(02:00:aa:0b:03:02 10.10.200.1/24)
addr_r1_user=(02:00:aa:01:0a:02 10.10.100.2/24)
addr_r1_r2=(02:00:aa:01:02:03 10.10.12.1/24)
addr_r1_r3=(02:00:aa:01:03:04 10.10.13.1/24)
addr_r2_r3=(02:00:aa:02:03:02 10.10.23.1/24)
addr_r2_r1=(02:00:aa:02:01:03 10.10.12.2/24)
addr_r3_r1=(02:00:aa:03:01:02 10.10.13.2/24)
addr_r3_r2=(02:00:aa:03:02:03 10.10.23.2/24)
addr_r3_serv=(02:00:aa:03:0b:04 10.10.200.2/24)

#create virt network
vm netcreate netname=net_user_r1 brname=br_user_r1 forward=no
vm netcreate netname=net_r1_r2 brname=br_r1_r2 forward=no
vm netcreate netname=net_r2_r3 brname=br_r2_r3 forward=no
vm netcreate netname=net_r1_r3 brname=br_r1_r3 forward=no
vm netcreate netname=net_r3_serv brname=br_r3_serv forward=no

#create VM
for vm in user server r{1..3}; do tmux kill-session -t frr-$vm; vm del $vm; done &>/dev/null
stdlog=$(vm create $distro --downloadonly "$@" |& tee /dev/tty)
imgf=$(sed -rn '${/^-[-rwx]{9}.? /{s/^.* //;p}}' <<<"$stdlog")
tmux new -s frr-user -d "vm create -n user ${distro} --net=default -p traceroute,tcpdump,nmap -nointeract -I=$imgf $*"
tmux new -s frr-serv -d "vm create -n server ${distro} --net=default -p traceroute,tcpdump,nmap -nointeract -I=$imgf $*"
tmux new -s frr-r1 -d "vm create -n r1 ${distro} --net=default -nointeract -I=$imgf $*"
tmux new -s frr-r2 -d "vm create -n r2 ${distro} --net=default -nointeract -I=$imgf $*"
vm create -n r3 ${distro} --net=default -nointeract -I=$imgf "$@"
echo "{INFO} waiting all frr-vm create process finished ..."
while tmux ls|grep ^frr-; do sleep 16; done

#attach interfaces to connecting the routers and workstations
vm add.if user   net_user_r1 -- --mac=${addr_user_r1}
vm add.if server net_r3_serv -- --mac=${addr_serv_r3}
vm add.if r1     net_user_r1 -- --mac=${addr_r1_user}
vm add.if r1     net_r1_r2   -- --mac=${addr_r1_r2}
vm add.if r1     net_r1_r3   -- --mac=${addr_r1_r3}
vm add.if r2     net_r2_r3   -- --mac=${addr_r2_r3}
vm add.if r2     net_r1_r2   -- --mac=${addr_r2_r1}
vm add.if r3     net_r1_r3   -- --mac=${addr_r3_r1}
vm add.if r3     net_r2_r3   -- --mac=${addr_r3_r2}
vm add.if r3     net_r3_serv -- --mac=${addr_r3_serv}

#waiting ssh available and copy tools in VMs
for vm in user server r{1..3}; do
	vm port-available -w $vm
	vm cpto -v $vm /bin/static-ip-to-mac-or-if.sh /bin/frr-install.sh  /bin
	vm exec -v $vm -- "{ systemctl stop firewalld; systemctl disable firewalld; } &>/dev/null;"
done

#apply static-ip to every network interface
vm exec -v user -- static-ip-to-mac-or-if.sh ${addr_user_r1[@]}
vm exec -v server -- static-ip-to-mac-or-if.sh ${addr_serv_r3[@]}
vm exec -v r1 -- static-ip-to-mac-or-if.sh ${addr_r1_user[@]}
vm exec -v r1 -- static-ip-to-mac-or-if.sh ${addr_r1_r2[@]}
vm exec -v r1 -- static-ip-to-mac-or-if.sh ${addr_r1_r3[@]}
vm exec -v r2 -- static-ip-to-mac-or-if.sh ${addr_r2_r3[@]}
vm exec -v r2 -- static-ip-to-mac-or-if.sh ${addr_r2_r1[@]}
vm exec -v r3 -- static-ip-to-mac-or-if.sh ${addr_r3_r1[@]}
vm exec -v r3 -- static-ip-to-mac-or-if.sh ${addr_r3_r2[@]}
vm exec -v r3 -- static-ip-to-mac-or-if.sh ${addr_r3_serv[@]}

#install frr on route VMs
for vm in r{1..3}; do
	vm exec -v $vm -- sysctl -w net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1
	vm exec -v $vm -- frr-install.sh
	vm exec -v $vm -- "sed -ri 's/(ospfd|zebra|staticd)=no/\\1=yes/' /etc/frr/daemons; systemctl restart frr"
done

#configure frr on route VMs
if_r1_user=$(vm exec r1 -- "ip -o link | awk -F'[ :]+' '/${addr_r1_user}/{print \$2}'")
vm exec -v r1 -- 'cat >>/etc/frr/frr.conf <<EOF
frr defaults traditional
hostname r1
service integrated-vtysh-config
!
router ospf
 ospf router-id 1.1.1.1
 redistribute connected
 passive-interface '"${if_r1_user}"'
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

if_r3_serv=$(vm exec r3 -- "ip -o link | awk -F'[ :]+' '/${addr_r3_serv}/{print \$2}'")
vm exec -v r3 -- 'cat >>/etc/frr/frr.conf <<EOF
frr defaults traditional
hostname r3
service integrated-vtysh-config
!
router ospf
 ospf router-id 3.3.3.3
 redistribute connected
 passive-interface '"${if_r3_serv}"'
 network 10.10.13.0/24 area 0
 network 10.10.23.0/24 area 0
 network 10.10.200.0/24 area 0
!
line vty
!
EOF
systemctl reload frr'

#add route for user and server, avoid: test packet is routed to the default route(libvirt default net)
if_user_r1=$(vm exec user -- "ip -o link | awk -F'[ :]+' '/${addr_user_r1}/{print \$2}'")
if_serv_r3=$(vm exec server -- "ip -o link | awk -F'[ :]+' '/${addr_serv_r3}/{print \$2}'")
vm exec -v user -- ip route add 10.10.0.0/16 via ${addr_r1_user[1]%/*} dev $if_user_r1 metric 99
vm exec -v server -- ip route add 10.10.0.0/16 via ${addr_r3_serv[1]%/*} dev $if_serv_r3 metric 99

#workaround: ensure service frr is started
for vm in r{1..3}; do vm exec $vm -- systemctl restart frr; done

#ping test before ospf route generated
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
