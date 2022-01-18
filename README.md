# Summary

[en] This project provides three fool-proof scripts **vm, ns, netns**; designed to simplify the steps for QE and developers to configure and use VM/Container/netns,
Thereby focusing more on the verification and testing of business functions.

[zh] 本项目提供了三个傻瓜化的脚本 **vm, ns, netns** ; 旨在简化测试和开发人员配置和使用 VM/Container/netns 的步骤，
从而更加聚焦业务功能的验证和测试。

```
vm:
        vm create $distro -n $vmname [other options]
        vm exec $vmname -- command line

netns:
        netns host,$vethX,$addr---$netns0,$vethX_peer,$addr  $netns0,$vnic_ifname[,$addr][?updev=$if,mode=$mode]
        netns exec $netns -- command line

ns:
        ns create $ns [other options]
        ns exec $ns -- command line
```

# Install
```
git clone https://github.com/tcler/kiss-vm-ns
sudo make -C kiss-vm-ns install && sudo vm prepare
```

# Examples
## kiss-vm

![kiss-vm](https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/Images/kiss-vm.gif)

example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-vm.sh  
example: https://github.com/tcler/freebsd-pnfsserver-in-kvm  
```
[me@ws ~]$ vm help  #get usage/help info
```

## kiss-ns
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/labelled-nfs/labelled-nfs.sh  
```
[me@ws ~]$ ns -h  #get usage/help info
```

## kiss-netns
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/nfs-stress/nfs-stress.sh#L85  
example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-netns.sh#L23  
```
[me@ws ~]$ netns -h  #get usage/help info
```
