# kiss-vm

![kiss-vm](https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/Images/kiss-vm.gif)

example: https://github.com/tcler/linux-network-filesystems/blob/master/drafts/nfs/testcases/multipath/multipath-vm.sh

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
    --nvdimm       #add 2 nvdimm device(2048+2M) //need qemu >= v2.6.0(RHEL/CentOS 8.0 or later)
    --nosshkey     #don't inject sshkey

Example Intranet:
    vm # will enter a TUI show you all available distros that could auto generate source url
    vm RHEL-6.10 -L
    vm RHEL-7.7
    vm RHEL-8.1.0 -f -p "vim wget git"
    vm RHEL-8.1.0 -L -brewinstall 23822847  # brew scratch build id
    vm RHEL-8.1.0 -L -brewinstall kernel-4.18.0-147.8.el8  # brew build name
    vm RHEL-8.1.0 -L -brewinstall "lstk -debug"            # latest brew build release debug kernel
    vm RHEL-8.2.0-20191024.n.0 -g -b "upk -debug"          # latest brew build upstream debug kernel

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
    vm start [VM]        #stop/shutdonw VM   //nil

    vm net               #list all virtual network
    vm net netname=testnet brname=virbrN subnet=100  #create virtual network 'testnet'
    vm netinfo testnet   #show detail info of virtual network 'testnet'
    vm netdel testnet    #delete virtual network 'testnet'
```

# kiss-ns

example: https://github.com/tcler/linux-network-filesystems/blob/master/drafts/nfs/testcases/labelled-nfs/labelled-nfs.sh


```
[me@ws kiss-vm-ns]$ ns -h
Usage:
  /usr/local/bin/ns <-n nsname> [options] [exec -- cmdline | ps | del | install pkgs | {jj|jinja} pkgs ]
  /usr/local/bin/ns ls

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
  /usr/local/bin/ns jj nsmini bash   # create a mini rootfs template
  /usr/local/bin/ns -n ns0 --veth-ip 192.168.0.1,192.168.0.2 --noboot -robind=/usr --clone nsmini
  /usr/local/bin/ns -n ns1 --veth-ip 192.168.1.1,192.168.1.2 --macvlan-ip 192.168.254.11 -bind=/usr --clone nsmini

Examples create ns by using absolute own fs tree:
  /usr/local/bin/ns jj nsbase iproute iputils nfs-utils firewalld   # create a base rootfs template
  /usr/local/bin/ns -n ns2 --veth-ip 192.168.2.1,192.168.2.2 --macvlan-ip 192.168.254.12,192.168.253.12 --clone nsbase
  /usr/local/bin/ns -n ns3 --veth-ip 192.168.3.1,192.168.3.2 --macvlan-ip 192.168.254.13,192.168.253.13 --clone nsbase

Examples sub-command:
  /usr/local/bin/ns ls                                # list all ns
  /usr/local/bin/ns ps ns2                            # show ps tree of ns2
  /usr/local/bin/ns del ns2                           # delete/remove ns2 but keep rootdir
  /usr/local/bin/ns delete ns2                        # delete/remove ns2 and it's rootdir
  /usr/local/bin/ns install ns2 cifs-utils            # install cifs-utils in ns2

  /usr/local/bin/ns exec ns2 ip addr show             # exec command in ns2
  /usr/local/bin/ns exec ns2 -- ls -l /               # exec command in ns2

  systemctl start nfs-server
  exportfs -o ro,no_root_squash "*:/usr/share"
  /usr/local/bin/ns exec ns2 -- mkdir -p /mnt/nfs              # exec command in ns2
  /usr/local/bin/ns exec ns2 -- showmount -e 192.168.2.1       # exec command in ns2
  /usr/local/bin/ns exec ns2 -- mount 192.168.2.1:/ /mnt/nfs   # exec command in ns2
  /usr/local/bin/ns exec ns2 -- showmount -e 192.168.254.254     # exec command in ns2
  /usr/local/bin/ns exec ns2 -- mount 192.168.254.254:/ /mnt/nfs # exec command in ns2
```
