![kiss-vm](https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/Images/kiss-vm.gif)

# Summary
Here we provide three CLI tools **vm, ns, netns** that used to auto create "Linux/FreeBSD/Windows VM", Container and "net ns" on Linux host.

# Install
```
curl -s https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/utils/kiss-update.sh|sudo bash && sudo vm prepare
#or
git clone https://github.com/tcler/kiss-vm-ns && sudo make -C kiss-vm-ns && sudo vm prepare
```

# FAQ & Examples
## kiss-vm

Q: how to create a CentOS/RockyLinux/Fedora KVM Guest from location(see also: virt-install --location option)?  
A: vm create $distro \[-n $vmname] \[-L | -l $localtion_url]  #if there's url in default distro.db, just use -L
```
vm create CentOS-9-stream -n centos9s -l http://mirror.stream.centos.org/9-stream/BaseOS/$(uname -m)/os/
```

Q: how to create a Linux KVM Guest from qcow image(see also: virt-install --import option)?  
A: vm create $distro \[-n $vmname] \[-I | -i $image_url]  #if there's url in default distro.db, just use -I
```
vm create openSUSE-leap-15.3
```

Q: how to get the distro list in default distro.db?  
A: vm create \<tab>\<tab>  #bash completion will show avalible distro list in distro.db
```
$ vm create #<tab><tab>
#<Enter>               CentOS-8-stream        RHEL-6%                Windows-10             Windows-server-2019    debian-9               fedora-33              openSUSE-leap-15.3
#<aDistroFamilyName>   CentOS-9-stream        RHEL-7%                Windows-11             Windows-server-2022    debian-testing         fedora-34              
CentOS-6               FreeBSD-12.3           RHEL-8%                Windows-7              archlinux              fedora-30              fedora-35              
CentOS-7               FreeBSD-13.0           RHEL-9%                Windows-server-2012r2  debian-10              fedora-31              fedora-rawhide         
CentOS-8               FreeBSD-14.0           Rocky-8                Windows-server-2016    debian-11              fedora-32              openSUSE-leap-15.2
```

Q: does kiss-vm support auto create FreeBSD Guest with sshd enabled?  
A: yes, it does (by using vncdotool)
```
vm create FreeBSD-13.0 --msize 4096 --dsize 120G 
```

Q: does kiss-vm support auto Windows/Windows-server Guest installing?  
A: yes, it does since v2.0.0 (by using answer-file-generator.sh), and like Linux/FreeBSD it enable sshd by default on Windows Guest and support ssh login without password
```
vm create Windows-10 -C ~/Downloads/Win10-Evaluation.iso -f
vm create Windows-11 -C ~/Downloads/Win11-Evaluation.iso -f
```

Q: does kiss-vm support auto installing other systems besides linux/freebsd/windows?  
A: not yet, but it support maually install other systems from iso/localtion/image/pxe ...
```
vm create OI -C ~/Downloads/OI-hipster-gui-20211031.iso
vm create Fedora-35 --pxe [--net=pxenet] [--diskless]
```

Q: How does kiss-vm realize automatic installation?  
A: We mainly achieve the goal of automation by implementing Redhat based kickstart file generator, cloud-init generator, windows answerfile generator; then in some special scenarios, we use [OCR](https://en.wikipedia.org/wiki/Optical_character_recognition) technology and [VNC CLI client](https://github.com/sibson/vncdotool) to solve the problem.
```
$ vm vnc jiyin-opensuse-leap-153 --get
[vncget@jiyin-opensuse-leap-153]:
jiyin-opensuse-leap-153:~ # exit
logout
jiyin-opensuse-leap-153 login: _
$ vm vnc jiyin-opensuse-leap-153 --putln=root --putln=redhat
[vncput@jiyin-opensuse-leap-153]> root key:enter redhat key:enter
$ vm vnc jiyin-opensuse-leap-153 --get
[vncget@jiyin-opensuse-leap-153]:
jiyin-opensuse-leap-153:~ # exit
logout
jiyin-opensuse-leap-153 login: root
Password:
Last login: Fri Apr 29 03:14:03 on tty1
openSUSE Leap 15.3 x86_64 (64-bit)
As "root" use the:
- zypper command for package management
- yast command for configuration management
Have a lot of fun...
jiyin-opensuse-leap-153:~ #
```

Q: Does kiss-vm support creating aarch64,s390x Guest on x86_64 host  
A: Yes, since kiss-vm v2.1.0. and it requires qemu-system-$arch has been installed on your x86_64 linux Host.
now we only verified that creating s390x,aarch64 RHEL-8/RHEL-9/c8s/c9s Guest on x86_64 Fedora-35/Fedora-36 Host.
```
vm create CentOS-8-stream --arch aarch64
vm create CentOS-9-stream --arch s390x
vm create CentOS-9-stream --arch aarch64
```

Q: What other functions or usages does kiss-mv support?  
A: just run: 'vm help' to get more usage/examples info; and there are some useful scirpts under the utils dir.


## kiss-ns
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/labelled-nfs/labelled-nfs-ns.sh  
```
[me@ws ~]$ ns -h  #get usage/help info
```

## kiss-netns
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/nfs-stress/nfs-stress.sh#L176  
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-netns.sh#L38  
```
[me@ws ~]$ netns -h  #get usage/help info
```
