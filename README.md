# Summary

[en] This project provides three fool-proof scripts **vm, ns, netns**; designed to simplify the steps for QE or developers to configure and use VM/Container/netns,
Thereby focusing more on the verification and testing of business functions.

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
curl -s https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/utils/kiss-update.sh|sudo bash
sudo vm prepare
```
or
```
git clone https://github.com/tcler/kiss-vm-ns
sudo make -C kiss-vm-ns install && sudo vm prepare
```

# Examples
## kiss-vm

![kiss-vm](https://raw.githubusercontent.com/tcler/kiss-vm-ns/master/Images/kiss-vm.gif)

example: https://github.com/tcler/linux-network-filesystems/blob/master/testcases/nfs/multipath/multipath-vm.sh  
example: https://github.com/tcler/freebsd-pnfsserver-in-kvm/blob/main/make-pnfsserver-demo.sh  
```
[me@ws ~]$ vm help  #get usage/help info
```

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
