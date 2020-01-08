# Summary

[en] This project provides three fool-proof scripts **vm, ns, netns**; designed to simplify the steps for QE and developers to configure and use VM/Container/netns,
Thereby focusing more on the verification and testing of business functions.

[zh] 本项目提供了三个傻瓜化的脚本 **vm, ns, netns** ; 旨在简化测试和开发人员配置和使用 VM/Container/netns 的步骤，
从而更加聚焦业务功能的验证和测试。

```
vm:
    功能: 快速创建、登陆、重启、删除 libvirt 虚拟机(VMs)，以及构建虚拟网络(Virtual lab);
    用途: 自动化测试 网络协议、网络文件系统、本地文件系统、nvdimm 等模块功能（硬件无关的功能都可以）
        vm create $distro [other options]
        vmname=$(vm -r -getvmname $distro)
        vm exec $vmname -- command line

ns:
    功能: 快速创建基于 systemd-nspawn 的容器(Container)网络
    用途: 自动化测试 网络协议、网络文件系统 功能
        ns create $ns [other options]
        ns exec $ns -- command line

netns:
    功能: 快速创建基于 ip-netns 的 network namespace 网络拓扑
    用途: 自动化测试 网络协议、以及部分网络文件系统 功能
        netns host,$vethX,$addr---$netns0,$vethX_peer,$addr  $netns0,$vnic_ifname[,$addr][?updev=$if,mode=$mode]
        netns exec $netns -- command line
```

# More details
## kiss-vm

![kiss-vm](https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/Images/kiss-vm.gif)

example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-vm.sh

```
[me@ws kiss-vm-ns]$ vm -h
Usage:
    vm [subcmd] <-d distroname> [OPTIONs] ...

Options:
    -h, --help     #Display this help.
    --prepare      #check/install/configure libvirt and other dependent packages
    -I             #create VM by import existing disk image, auto search url according distro name
                    `-> just could be used in Intranet
    -i <url/path>  #create VM by import existing disk image, value can be url or local path
    -L             #create VM by using location, auto search url according distro name
                    `-> just could be used in Intranet
    -l <url>       #create VM by using location
    --ks <file>    #kickstart file, will auto generate according distro name if omitting
    -n|--vmname <name>
                   #VM name, will auto generate according distro name if omitting
    --getvmname    #get *final* vmname. e.g:
                     vm -r --getvmname centos-8 -n nfsserv
                     vmname=$(vm -r --getvmname centos-8 -n nfsserv)
    -f|--force     #over write existing VM with same name
    -p|-pkginstall <pkgs>
                   #pkgs in default system repo, install by yum or apt-get
    -b|-brewinstall <args>
                   #pkgs in brew system or specified by url, install by internal brewinstall.sh
                    `-> just could be used in Intranet
    -g|-genimage   #generate VM image, after install shutdown VM and generate new qcow2.xz file
    --rm           #like --rm option of docker/podman, remove VM after quit from console
    --nocloud|--nocloud-init
                   #don't create cloud-init iso for the image that is not cloud image
    --osv <variant>
                   #OS_VARIANT, optional. virt-install will attempt to auto detect this value
                   # you can get [-osv variant] info by using:
                   $ osinfo-query os  #RHEL-7 and later
                   $ virt-install --os-variant list  #RHEL-6
    --nointeract   #exit from virsh console after install finish
    --saveimage [path]
                   #save image in path if install with import mode
    --cpus <N>     #number of virtual cpus, default 4
    --msize <size> #memory size, default 2048
    --dsize <size> #disk size, default 16
    --net <$name>  #join libvirt net $name
    --netmacvtap [source NIC]
                   #attach a macvtap interface
    --macvtapmode <vepa|bridge>
                   #macvtap mode
    -r|--ready     #virt config is ready, don't have to run enable_libvirt function
    --xdisk        #add 2 extra disk for test
    --nvdimm <nvdimm list>
                   #one or more nvdimm specification, format: 511+1 (targetSize+labelSize)
                   #e.g: --nvdimm="511+1 1023+1" -> two nvdimm device
                   #e.g: --nvdimm="511 1023" -> two nvdimm device
                   #               ^^^^^^^^ default labelSize is 1, if omitting
                   #note: nvdimm function need qemu >= v2.6.0(RHEL/CentOS 8.0 or later)
    --nosshkey     #don't inject sshkey
    -v|--verbose   #verbose mode
    --xml          #just generate xml
    --qemu-opts    #Pass-through qemu options
    --qemu-env     #Pass-through qemu env[s]

Example Intranet:
    vm # will enter a TUI show you all available distros that could auto generate source url
    vm RHEL-7.7                           # install RHEL-7.7 from cloud-image(by default)
    vm RHEL-6.10 -L                       # install RHEL-6.10 from Location(by -L option)

    vm RHEL-8.1.0 -f -p "vim wget git"    # -f force install VM and ship pkgs: vim wget git
    vm RHEL-8.1.0 -brewinstall 23822847   # ship brew scratch build pkg (by task id)
    vm RHEL-8.1.0 -brewinstall kernel-4.18.0-147.8.el8  # ship brew build pkg (by build name)
    vm RHEL-8.1.0 -brewinstall "lstk -debug"            # ship latest brew build release debug kernel
    vm RHEL-8.1.0 -brewinstall "upk -debug"             # ship latest brew build upstream debug kernel
    vm RHEL-8.1.0 --nvdimm "511 1022+2"                 # add two nvdimm device
    vm rhel-8.2.0%                        # nightly 8.2 # fuzzy search distro: ignore-case
    vm rhel-8.2*-????????.?               # rtt 8.2     # - and only support glob * ? syntax, and SQL %(same as *)

Example Internet:
    vm centos-5 -l http://vault.centos.org/5.11/os/x86_64/
    vm centos-6 -l http://mirror.centos.org/centos/6.10/os/x86_64/
    vm centos-7 -l http://mirror.centos.org/centos/7/os/x86_64/
    vm centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/
    vm centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ -brewinstall ftp://url/path/x.rpm
    vm centos-7 -i https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz -pkginstall "vim git wget"
    vm debian-10 -i https://cdimage.debian.org/cdimage/openstack/10.1.5-20191015/debian-10.1.5-20191015-openstack-amd64.qcow2

Example from local image:
    vm rhel-8-up -i ~/myimages/RHEL-8.1.0-20191015.0/rhel-8-upstream.qcow2.xz --nocloud-init
    vm debian-10 -i /mnt/vm-images/debian-10.1.5-20191015-openstack-amd64.qcow2

Example [subcmd]:
    vm list              #list all VMs       //you can use ls,li,lis* instead list
    vm login [/c] [VM]   #login VM           //you can use l,lo,log* instead login
    vm delete [VM list]  #delete VMs         //you can use d,de,del*,r,rm instead delete
    vm ifaddr [VM]       #show ip address    //you can use i,if,if* instead ifaddr
    vm vncport [VM]      #show vnc host:port //you can use v,vnc instead vncport
    vm edit [VM]         #edit vm xml file   //you can use ed,ed* instead edit
    vm exec "$VM" -- "cmd"  #login VM and exec cmd  //you can use e,ex,ex* instead exec
    vm reboot [/w] [VM]  #reboot VM          //option /w indicate wait until reboot complete(port 22 is available)
    vm stop [VM]         #stop/shutdonw VM   //nil
    vm start [VM]        #start VM           //nil

    vm net               #list all virtual network
    vm net netname=testnet brname=virbrN subnet=100  #create virtual network 'testnet'
    vm netinfo testnet   #show detail info of virtual network 'testnet'
    vm netdel testnet    #delete virtual network 'testnet'
```

## kiss-ns

example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/labelled-nfs/labelled-nfs.sh

```
[me@ws kiss-vm-ns]$ ns -h
Usage:
  ns <-n nsname> [options] [exec -- cmdline | ps | del | install pkgs | {jj|jinja} pkgs ]
  ns ls

Options:
  -h, --help           ; show this help info
  -n {nsname}          ; ns(name space) name
  -p {pkgs}            ; packages you want in ns(name space)
  -d                   ; debug mode
  -v                   ; verbose mode, output more info
  --veth-ip {ip1,ip2}  ; ip address pair for veth pair; ip1 for host side and ip2 for ns side
  --macvlan-ip {ip1[,ip2...]} ; ip address[es] for ns macvlan if[s]; all for ns side
  --bind {src[:dst]}   ; see systemd-nspawn --bind
  --robind {src[:dst]} ; see systemd-nspawn --bind-ro
  --vol, --volatile {yes|no}  ; see systemd-nspawn --volatile. default is no
  --clone {ns}         ; clone from ns
  --noboot             ; no boot
  -x                   ; see systemd-nspawn -x, need btrfs as rootfs

Examples create ns by using mini fs tree + host /usr:
  # same as example ns1, but use a it's own fs tree instead reuse host os tree
  #  so you can do anything in this ns, and don't worry about any impact on the host
  ns jj nsmini bash   # create a mini rootfs template
  ns -n ns0 --veth-ip 192.168.0.1,192.168.0.2 --noboot -robind=/usr --clone nsmini
  ns -n ns1 --veth-ip 192.168.1.1,192.168.1.2 --macvlan-ip 192.168.254.11 -bind=/usr --clone nsmini

Examples create ns by using absolute own fs tree:
  ns jj nsbase iproute iputils nfs-utils firewalld   # create a base rootfs template
  ns -n ns2 --veth-ip 192.168.2.1,192.168.2.2 --macvlan-ip 192.168.254.12,192.168.253.12 --clone nsbase
  ns -n ns3 --veth-ip 192.168.3.1,192.168.3.2 --macvlan-ip 192.168.254.13,192.168.253.13 --clone nsbase

Examples sub-command:
  ns ls                                # list all ns
  ns ps ns3                            # show ps tree of ns3
  ns del ns3                           # delete/remove ns3 but keep rootdir
  ns delete ns3                        # delete/remove ns3 and it's rootdir
  ns install ns2 cifs-utils            # install cifs-utils in ns2

  ns exec ns2 ip addr show             # exec command in ns2
  ns exec ns2 -- ls -l /               # exec command in ns2

  sudo systemctl start nfs-server
  sudo exportfs -o ro,no_root_squash "*:/usr/share"
  sudo addmacvlan macvlan-host
  sudo addressup macvaln-host 192.168.254.254
  sudo firewall-cmd --add-service=nfs --add-service=mountd --add-service=rpc-bind
  ns exec ns2 -- mkdir -p /mnt/nfs              # exec command in ns2
  ns exec ns2 -- showmount -e 192.168.2.1       # exec command in ns2
  ns exec ns2 -- mount 192.168.2.1:/ /mnt/nfs   # exec command in ns2
  ns exec ns2 -- showmount -e 192.168.254.254     # exec command in ns2
  ns exec ns2 -- mount 192.168.254.254:/ /mnt/nfs # exec command in ns2
```

## kiss-netns

example1: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/nfs-stress/nfs-stress.sh#L85  
example2: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-netns.sh#L23

```
[me@ws kiss-vm-ns]$ netns
Usage:
  netns <$nsname,$vethX,$addr---$nsname,$vethX_peer,$addr | $nsname,$vnic_name[,$addr][?updev=$if,mode=$mode,iftype=$iftype]>
  # ^^^ nsname 'host' means default network namespace, br-* means it's a bridge //[convention over configuration]
  # ^^^ vnic_name 'iv-*' means ipvlan nic, 'mv-*' and others means macvlan nic //[convention over configuration]

  # +--------+                            +--------+
  # | ns0    [veth0.X]------------[veth0.Y] host   |
  # +--------+                            +--------+
  # netns ns0,veth0.X,192.168.1.2---host,veth0.Y,192.168.1.1

  # +--------+                            +--------+
  # | ns0    [veth1.X]------------[veth1.Y] ns1    |
  # +--------+                            +--------+
  # netns ns0,veth1.X,192.168.2.2---ns1,veth1.Y,192.168.2.1

  # +--------+                    +------+                    +--------+
  # | ns0    [veth3.X]----[veth3.Y] br-0 [veth4.X]----[veth4.Y] ns1    |
  # +--------+                    +------+                    +--------+
  # netns ns0,veth3.X,192.168.3.2---br-0,veth3.Y  br-0,veth4.X---ns1,veth4.Y,192.168.3.1

  # +--------+                            +--------+
  # |        [veth5.X]------------[veth5.Y]        |
  # | ns0    |                            | ns1    |
  # |        [mv-ns0]              [mv-ns1]        |
  # +--------+    \                  /    +--------+
  #                \                /
  #               +------------------+
  #               | mv-ns0  | mv-ns1 |
  #               +------------------|
  #               |       eth0       |
  #               +------------------+
  # netns ns0,veth5.X,192.168.4.2---ns1,veth5.Y,192.168.4.1  ns0,mv-ns0,192.168.5.10  ns1,mv-ns1,192.168.5.11

  netns exec $nsname -- cmdline
  netns del $nsname
  netns ls

  netns veth ve0.a-host,ve0.b-ns0   #create veth pair
  netns macvlan ifname              #create macvlan if; [updev=updev] [mode={bridge|vepa|private|passthru}]
  netns ipvlan ifname               #create ipvlan if; [updev=updev] [mode={l2|l3}]

  netns addrup $if $address         #set address and up if
  netns addif2netns $ns $if [$addr] #add new if to netns, [and setup address and up]
  netns detach $ns $if              #detach if from netns

Options:
  -h, --help           ; show this help info
  -v                   ; verbose mode
  -n <arg>             ; netns name

Examples: host connect ns0 with both veth and macvlan
  netns host,ve0.a-host,192.168.0.1---ns0,ve0.b-ns0,192.168.0.2  host,mv-host0,192.168.100.1 ns0,mv-ns0,192.168.100.2
  netns -v exec ns0 -- ping -c 2 192.168.0.1
  netns -v exec ns0 -- ping -c 2 192.168.100.1
  #curl -s -L https://raw.githubusercontent.com/tcler/linux-network-filesystems/master/tools/configure-nfs-server.sh | sudo bash
  sudo systemctl start nfs-server
  sudo exportfs -o ro,no_root_squash "*:/usr/share"
  netns -v exec ns0 -- showmount -e 192.168.0.1
  netns -v exec ns0 -- mkdir -p /mnt/ns0/nfs
  netns -v exec ns0 -- mount 192.168.0.1:/ /mnt/ns0/nfs
  netns -v exec ns0 -- mount -t nfs4
  netns -v exec ns0 -- ls /mnt/ns0/nfs/*
  netns -v exec ns0 -- umount /mnt/ns0/nfs
  netns -v exec ns0 -- rm -rf /mnt/ns0
  netns del ns0
  netns delif mv-host0

Examples: host connect ns0 with both veth and ipvlan
  netns host,ve0.a-host,192.168.0.1---ns0,ve0.b-ns0,192.168.0.2   host,iv-host0,192.168.99.1 ns0,iv-ns0,192.168.99.2
  netns -v exec ns0 -- ping -c 2 192.168.99.1
  netns del ns0
  netns delif iv-host0

Examples: host connect ns0 with veth and bridge br-0
  netns host,veth0.X,192.168.66.1---br-0,veth0.Y  br-0,veth1.Y---ns0,veth1.X,192.168.66.2
  netns -v exec ns0 -- ping -c 2 192.168.66.1
  netns del ns0 br-0

```
