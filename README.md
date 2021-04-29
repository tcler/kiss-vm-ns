# Summary

[en] This project provides three fool-proof scripts **vm, ns, netns**; designed to simplify the steps for QE and developers to configure and use VM/Container/netns,
Thereby focusing more on the verification and testing of business functions.

[zh] 本项目提供了三个傻瓜化的脚本 **vm, ns, netns** ; 旨在简化测试和开发人员配置和使用 VM/Container/netns 的步骤，
从而更加聚焦业务功能的验证和测试。

```
vm:
    功能: 快速创建、登陆、重启、删除 libvirt 虚拟机(VMs)，以及构建虚拟网络(Virtual lab);
    用途: 自动化测试 网络协议、网络文件系统、本地文件系统、nvdimm 等模块功能（硬件无关的功能都可以）
        vm create $distro -n $vmname [other options]
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
  vm [create] <distro_or_family_name> [OPTIONs] ...
  vm <$other_subcmd> [OPTIONs] ...

Options:
  -h,--help      #Display this help.

Options for sub-command create:
  -I             #create VM by import existing disk image, auto search url according distro name
  -i <url/path>  #create VM by import existing disk image, value can be url or local path
  -L             #create VM by using location, auto search url according distro name
  -l <url>       #create VM by using specified location url or local iso file path
  -C <iso path>  #create VM by using ISO image
  --ks <file>    #kickstart file, will auto generate according distro name if omitting
  -n,--vmname <name>
                 #VM name, will auto generate according distro name if omitting
  -f,--force     #over write existing VM with same name
  -p,--pkginstall <pkgs>
                 #pkgs in default system repo, install by yum or apt-get
  -b,--brewinstall <args>
                 #pkgs in brew system or specified by url, install by internal brewinstall.sh
                  `-> just could be used in Intranet
  -g,--genimage  #generate VM image, after install shutdown VM and generate new qcow2.xz file
  --rm           #like --rm option of docker/podman, remove VM after quit from console
  --nocloud,--nocloud-init
                 #don't create cloud-init iso for the image that is not cloud image
  --osv <variant>
                 #OS_VARIANT, optional. virt-install will attempt to auto detect this value
                 # you can get [-osv variant] info by using:
                 $ osinfo-query os  #RHEL-7 and later
                 $ virt-install --os-variant list  #RHEL-6
  --nointeract   #exit from virsh console after install finish
  --noauto       #enter virsh console after installing start
  --saveimage [path]
                 #save image in path if install with import mode
  --downloadonly #download image only if there is qcow* image
  --cpus <N>     #number of virtual cpus, default 4
  --msize <size> #memory size, default 2048
  --dsize <size> #disk size, default 16
  --net <$name[,$model]>
                 #attach tun dev(vnetN) and connect to net $name, optional $model: virtio,e1000,...
  --net-br <$brname[,$model]>
                 #attach tun dev(vnetN) and connect to bridge $brname, optional $model: virtio,e1000,...
  --net-macvtap,--netmacvtap [$sourceNIC[,$model]]
                 #attach macvtap interface over $sourceNIC, optional $model: virtio,e1000,...
  --macvtapmode <vepa|bridge>
                 #macvtap mode
  -r,--ready     #virt config is ready, don't have to run enable_libvirt function
  --xdisk <size[,fstype]>
                 #add an extra disk, could be specified multi-times. size unit is G
                 #`e.g: --xdisk 10 --xdisk 20,xfs
  --disk <img[,bus=]>
                 #add exist disk file, could be specified multi-times.
  --bus <$boot_disk_bus>
  --sharedir <shpath[:target]>
                 #share path between host and guest
  --nvdimm <nvdimm list>
                 #one or more nvdimm specification, format: 511+1 (targetSize+labelSize)
                 #`e.g: --nvdimm="511+1 1023+1" -> two nvdimm device
                 #`e.g: --nvdimm="511 1023" -> two nvdimm device
                 #               ^^^^^^^^ default labelSize is 1, if omitting
                 #Note: will exit if qemu on your system does not support nvdimm, check by:
                 # PATH=$PATH:/usr/libexec qemu-kvm -device help | grep nvdimm
  --nvme <size=[,format=]>
                 #one or more nvme specification.
                 #`e.g: --nvme=size=10 --nvme=size=20,format=raw
                 #size units: GB, default format is qcow2
                 #Note: will exit if qemu on your system does not support nvme, check by:
                 # PATH=$PATH:/usr/libexec qemu-kvm -device help | grep nvme
  --vtpm         #enable virtual tpm
  --kdump        #enable kdump
  --fips         #enable fips
  --postrepo <name:url>
                 #add dnf/yum <repo> after install, only for CentOS/RHEL/Fedora
                 #`e.g: --postrepo=beaker-tasks:http://beaker.engineering.fedora.com/rpms
  --nosshkey     #don't inject sshkey
  --debug        #debug mode
  --vncput-after-install <msg>
                 #send string or key event ASAP after virt-intall
  --xml          #just generate xml
  --machine <machine type>
                 #specify machine type #get supported type by: qemu-kvm -machine help
  --virt-install-opts #Pass-through virt-install options
  --qemu-opts    #Pass-through qemu options
  --qemu-env     #Pass-through qemu env[s]
  --enable-guest-hypv #enable guest hypervisor, same as --qemu-opts="-cpu host,+vmx" or --qemu-opts="-cpu host,+svm"
                      #ref: https://www.linux-kvm.org/page/Nested_Guests
  --disable-guest-hypv #disable guest hypervisor
  --pxe          #PXE install
                 #`e.g: vm fedora-32 -n f32 -net-macvtap -pxe --noauto -f
  --diskless     #diskless install
                 #`e.g: vm fedora-32 -n f32-diskless --net pxenet --pxe --diskless -f
  -v,--verbose   #verbose mode
  -q             #quiet mode, intend suppress the outputs of command yum, curl

Options for sub-command reboot:
  -w,--wait      #wait util the 22 port(sshd) is available after reboot

Options for sub-command exec:
  -v,--verbose   #verbose mode
  -x[arg]        #expected return code of sub-command exec, if doesn't match output test fail msg
                 #`e.g: -x  or  -x0  or  -x1,2,3  or  -x1,10,100-200

Options for sub-command vncproc:
  --get,--vncget #get vnc screen and convert to text by gocr
  --put,--vncput <msg>
		 #send string or key event to vnc server, could be specified multi-times
		 #`e.g: --put root --put key:enter --put password --put key:enter
  --putln,--vncputln <msg>
		 #alias of: --put msg --put key:enter

Examples for create vm from distro-db (Intranet):
  vm [create] # will enter a TUI show you all available distros that could auto generate source url
  vm [create] RHEL-7.7                           # install RHEL-7.7 from cloud-image(by default)
  vm [create] RHEL-6.10 -L                       # install RHEL-6.10 from Location(by -L option)

  vm [create] RHEL-8.1.0 -f -p "vim wget git"    # -f force install VM and ship pkgs: vim wget git
  vm [create] RHEL-8.1.0 -brewinstall 23822847   # ship brew scratch build pkg (by task id)
  vm [create] RHEL-8.1.0 -brewinstall kernel-4.18.0-147.8.el8  # ship brew build pkg (by build name)
  vm [create] RHEL-8.1.0 -brewinstall "lstk -debug"            # ship latest brew build release debug kernel
  vm [create] RHEL-8.1.0 -brewinstall "upk -debug"             # ship latest brew build upstream debug kernel
  vm [create] RHEL-8.1.0 --nvdimm "511 1022+2"                 # add two nvdimm device
  vm [create] RHEL-8.3.0 --nvme "size=32 size=16,format=raw"   # add two nvme device
  vm [create] rhel-8.2.0%                        # nightly 8.2 # fuzzy search distro: ignore-case
  vm [create] rhel-8.2*-????????.?               # rtt 8.2     # - and only support glob * ? syntax, and SQL %(same as *)
  vm [create] rhel-8.2% -enable-guest-hypv -msize=$((8*1024)) -dsize=120  # enable hyper-v on guest

Examples for create vm from distro-db (Internet):
  vm [create] # will enter a TUI show you all available distros that could auto generate source url
  vm [create] CentOS-8-stream -b ftp://url/path/x.rpm
  vm [create] CentOS-8 -p "jimtcl vim git make gcc"
  vm [create] CentOS-7 -p "vim git wget make gcc"
  vm [create] CentOS-6
  vm [create] fedora-32
  vm [create] centos-5 -l http://vault.centos.org/5.11/os/x86_64/
  vm [create] debian-10 -i https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2
  vm [create] openSUSE-leap-15.2
  vm [create] CentOS-7 -enable-guest-hypv -msize=$((8*1024)) -dsize=120  # enable hyper-v on guest

Examples for create vm from local image:
  vm [create] rhel-8-up -i ~/myimages/RHEL-8.1.0-20191015.0/rhel-8-upstream.qcow2.xz --nocloud-init
  vm [create] debian-10 -i /mnt/vm-images/debian-10-openstack-amd64.qcow2
  vm [create] openSUSE-leap-15.2 -i ~/myimages/openSUSE-Leap-15.2-OpenStack.x86_64.qcow2

Examples for other sub-commands:
  vm prepare           #check/install/configure libvirt and other dependent packages
  vm enable-nested-vm  #enable nested on host

  vm list              #list all VMs       //you can use ls,li,lis* instead list
  vm login [VM]        #login VM via ssh   //you can use l,lo,log* instead login
  vm console [VM]      #log VM via console //you can use co,con,cons* instead console
  vm delete [VM list]  #delete VMs         //you can use d,de,del*,r,rm instead delete
  vm ifaddr [VM]       #show ip address    //you can use i,if,if* instead ifaddr
  vm vnc [VM]          #show vnc host:port //you can use v,vn instead
  vm vnc [-get|-put|-putln] [VM]           #read screen text or send string thru vnc
  vm xml [VM]          #dump vm xml file   //you can use x,xm instead xml
  vm edit [VM]         #edit vm xml file   //you can use ed,ed* instead edit
  vm exec [-v] [-x] "$VM" -- "cmd"  #login VM and exec cmd  //you can use e,ex,ex* instead exec
  vm reboot [-w] [VM]  #reboot VM          //option /w indicate wait until reboot complete(port 22 is available)
  vm stop [VM]         #stop/shutdonw VM   //nil
  vm start [VM]        #start VM           //nil
  vm cpfrom <VM> <file/dir_in_vm> <dst_dir/file_in_host>
  vm cpto   <VM> <files/dirs_in_host ...> <dst_dir_in_vm>

  vm netls             #list all virtual network
  vm netcreat netname=nat-net brname=virbrM subnet=10 [forward=nat]  #create network 'nat-net' with 'nat' and subnet: 192.168.10.0
  vm netcreat netname=isolated-net brname=virbrN subnet=20 forward=no  #create network 'isolated-net' with subnet: 192.168.20.0
  vm netcreat netname=pxe brname=virpxebrN subnet=172.25.250.0 tftproot=/var/lib/tftpboot bootpfile=pxelinux/pxelinux.0
  vm netinfo netname   #show detail info of virtual network 'netname'
  vm netstart netname  #start virtual network 'netname'
  vm netdel netname    #delete virtual network 'netname'

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
  -x[arg]              ; expected return code of sub-command exec, if doesn't match output test fail msg
                       ; e.g: -x  or  -x0  or  -x1,2,3  or  -x1,10,100-200

Examples create ns by using mini fs tree + host /usr:
  # same as example ns1, but use a it's own fs tree instead reuse host os tree
  #  so you can do anything in this ns, and don't worry about any impact on the host
  ns jj nsmini bash   # create rootfs template nsmini
  ns -n ns0 --veth-ip 192.168.0.1,192.168.0.2 --noboot -robind=/usr --clone nsmini
  ns -n ns1 --veth-ip 192.168.1.1,192.168.1.2 --macvlan-ip 192.168.254.11 -bind=/usr --clone nsmini

Examples create ns by using absolute own fs tree:
  ns jj nsbase iproute iputils nfs-utils --clone nsmini   # create rootfs template nsbase
  ns -n ns2 --veth-ip 192.168.2.1,192.168.2.2 --macvlan-ip 192.168.254.12,192.168.253.12 --clone nsbase
  ns -n ns3 --veth-ip 192.168.3.1,192.168.3.2 --macvlan-ip 192.168.254.13,192.168.253.13 --clone nsbase

Examples sub-command:
  ns ls                                # list all ns
  ns ps ns3                            # show ps tree of ns3
  ns del ns3                           # delete/remove ns3 but keep rootdir
  ns delete ns3                        # delete/remove ns3 and it's rootdir
  ns install ns2 cifs-utils            # install cifs-utils in ns2

  ns exec -v -x ns2 ip addr show             # exec command in ns2
  ns exec -v -x ns2 -- ls -l /               # exec command in ns2

  sudo systemctl start nfs-server
  sudo exportfs -o ro,no_root_squash "*:/usr/share"
  sudo addmacvlan macvlan-host
  sudo addressup macvlan-host 192.168.254.254
  sudo firewall-cmd --add-service=nfs --add-service=mountd --add-service=rpc-bind
  ns exec -v -x ns2 -- mkdir -p /mnt/nfs                # exec command in ns2
  ns exec -v -x ns2 -- showmount -e 192.168.2.1         # exec command in ns2
  ns exec -v -x ns2 -- mount 192.168.2.1:/ /mnt/nfs     # exec command in ns2
  ns exec -v -x ns2 -- showmount -e 192.168.254.254     # exec command in ns2
  ns exec -v -x ns2 -- mount 192.168.254.254:/ /mnt/nfs # exec command in ns2

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
  -x[arg]              ; expected return code of sub-command exec, if doesn't match output test fail msg
                       ; e.g: -x  or  -x0  or  -x1,2,3  or  -x1,10,100-200

Examples: host connect ns0 with both veth and macvlan
  netns host,ve0.a-host,192.168.0.1---ns0,ve0.b-ns0,192.168.0.2  host,mv-host0,192.168.100.1 ns0,mv-ns0,192.168.100.2
  netns exec -v -x ns0 -- ping -c 2 192.168.0.1
  netns exec -v -x ns0 -- ping -c 2 192.168.100.1
  #curl -s -L https://raw.githubusercontent.com/tcler/linux-network-filesystems/master/tools/configure-nfs-server.sh | sudo bash
  sudo systemctl start nfs-server
  sudo exportfs -o ro,no_root_squash "*:/usr/share"
  sudo firewall-cmd --add-service=nfs --add-service=mountd --add-service=rpc-bind
  netns exec -v -x ns0 -- showmount -e 192.168.0.1
  netns exec -v -x ns0 -- mkdir -p /mnt/ns0/nfs
  netns exec -v -x ns0 -- mount 192.168.0.1:/ /mnt/ns0/nfs
  netns exec -v -x ns0 -- mount -t nfs4
  netns exec -v    ns0 -- ls /mnt/ns0/nfs
  netns exec -v -x ns0 -- umount /mnt/ns0/nfs
  netns exec -v -x32 ns0 -- umount /mnt/ns0/nfs
  netns exec -v -x   ns0 -- umount /mnt/ns0/nfs  #just for show what does -x option work, when test fail
  netns exec -v    ns0 -- rm -rf /mnt/ns0
  netns del ns0
  netns delif mv-host0

Examples: host connect ns0 with both veth and ipvlan
  netns host,ve0.a-host,192.168.0.1---ns0,ve0.b-ns0,192.168.0.2   host,iv-host0,192.168.99.1 ns0,iv-ns0,192.168.99.2
  netns exec -v -x ns0 -- ping -c 2 192.168.99.1
  netns del ns0
  netns delif iv-host0

Examples: host connect ns0 with veth and bridge br-0
  netns host,veth0.X,192.168.66.1---br-0,veth0.Y  br-0,veth1.Y---ns0,veth1.X,192.168.66.2
  netns exec -v -x ns0 -- ping -c 2 192.168.66.1
  netns del ns0 br-0

```
