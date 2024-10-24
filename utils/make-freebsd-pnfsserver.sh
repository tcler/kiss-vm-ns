#!/bin/bash

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }

timeServer=clock.corp.redhat.com
host $timeServer|grep -q not.found: && timeServer=2.fedora.pool.ntp.org
TIME_SERVER=$timeServer
downhostname=download.devel.redhat.com
LOOKASIDE_BASE_URL=${LOOKASIDE:-http://${downhostname}/qa/rhts/lookaside}

#-------------------------------------------------------------------------------
#kiss-vm should have been installed and initialized
vm prepare >/dev/null

Cleanup() {
	rm -f $stdlogf
	exit
}
trap Cleanup EXIT #SIGINT SIGQUIT SIGTERM

[[ $# -ge 1 && $1 != -* ]] && { distro=${1:-9}; shift;
	[[ $# -ge 1 && $1 != -* ]] && { clientvm=${1:-ontap-rhel-client}; shift; }; }
distro=${distro:-9}
clientvm=${clientvm:-fbpnfs-linux-client}

#create freebsd VMs
#-------------------------------------------------------------------------------
freebsd_nvr="FreeBSD-12.4"
nfs4minver=1
freebsd_nvr="FreeBSD-14.1"
nfs4minver=2
vm_ds1=freebsd-pnfs-ds1
vm_ds2=freebsd-pnfs-ds2
vm_mds=freebsd-pnfs-mds
vm_fbclient=freebsd-pnfs-client

pkgs=nfs-utils,expect,iproute-tc,kernel-modules-extra,vim,bind-utils,tcpdump

stdlogf=/tmp/std-$$.log
vm create --downloadonly $freebsd_nvr 2>&1 | tee $stdlogf
imagef=$(sed -n '${s/^.* //; p}' $stdlogf)
if [[ ! -f "$imagef" ]]; then
	echo "{WARN} seems cloud image file download fail." >&2
	exit 1
fi
if [[ $imagef = *.xz ]]; then
	echo "{INFO} decompress $imagef ..."
	xz -d $imagef
	imagef=${imagef%.xz}
	if [[ ! -f ${imagef} ]]; then
		echo "{WARN} there is no $imagef, something was wrong." >&2
		exit 1
	fi
fi

echo -e "\n{INFO} remove existed VMs ..."
vm del freebsd-pnfs-ds1 freebsd-pnfs-ds2 freebsd-pnfs-mds freebsd-pnfs-client

echo -e "\n{INFO} creating VMs ..."
trun -tmux /usr/bin/vm create $distro -n $clientvm -p $pkgs --saveimage -f --nointeract "${@}"
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds1 -dsize 80 -i $imagef -f --nointeract
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds2 -dsize 80 -i $imagef -f --nointeract
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_mds -dsize 40 -i $imagef -f --nointeract
trun       /usr/bin/vm create $freebsd_nvr -n $vm_fbclient -i $imagef -f --nointeract

echo -e "\n{INFO} waiting VMs install finish ..."

#config freebsd pnfs ds server
for dsserver in $vm_ds1 $vm_ds2; do
	vm port-available -w ${dsserver}
	echo -e "\n{INFO} setup ${dsserver}:"
	cpfile=freebsd-pnfs-ds.sh; [[ -f "$cpfile" ]] || cpfile=/usr/bin/$cpfile
	vm cpto    ${dsserver} $cpfile /usr/bin
	vm exec -v ${dsserver} $cpfile
	vm exec -v ${dsserver} -- showmount -e localhost
done

#config freebsd pnfs mds server
echo -e "\n{INFO} setup ${vm_mds}:"
ds1addr=$(vm ifaddr $vm_ds1|head -1)
ds2addr=$(vm ifaddr $vm_ds2|head -1)
vm port-available -w ${vm_mds}
cpfile=freebsd-pnfs-mds.sh; [[ -f "$cpfile" ]] || cpfile=/usr/bin/$cpfile
vm cpto    ${vm_mds} $cpfile /usr/bin
vm exec -v ${vm_mds} $cpfile $ds1addr $ds2addr
vm exec -v ${vm_mds} -- mount -t nfs
vm exec -v ${vm_mds} -- showmount -e localhost

#config freebsd pnfs client
echo -e "\n{INFO} setup ${vm_fbclient}:"
vm port-available -w ${vm_fbclient}
cpfile=freebsd-pnfs-client.sh; [[ -f "$cpfile" ]] || cpfile=/usr/bin/$cpfile
vm cpto    ${vm_fbclient} $cpfile /usr/bin
vm exec -v ${vm_fbclient} ${cpfile}

#mount test from freebsd client
expdir0=/export0
expdir1=/export1
echo -e "\n{INFO} test from ${vm_fbclient}:"
nfsmp=/mnt/nfsmp
nfsmp2=/mnt/nfsmp2
mdsaddr=$(vm ifaddr $vm_mds|head -1)
vm exec -v ${vm_fbclient} -- mkdir -p $nfsmp $nfsmp2
vm exec -v ${vm_fbclient} -- mount -t nfs -o nfsv4,minorversion=$nfs4minver,pnfs $mdsaddr:$expdir0 $nfsmp
vm exec -v ${vm_fbclient} -- mount -t nfs -o nfsv4,minorversion=$nfs4minver,pnfs $mdsaddr:$expdir1 $nfsmp2
vm exec -v ${vm_fbclient} -- mount -t nfs
vm exec -v ${vm_fbclient} -- sh -c "echo 0123456789abcdef >$nfsmp/testfile"
vm exec -v ${vm_fbclient} -- sh -c "echo 0123456789abcdef >$nfsmp2/testfile"

vm exec -v ${vm_fbclient} -- ls -l $nfsmp/testfile
vm exec -v ${vm_fbclient} -- cat $nfsmp/testfile

vm exec -v ${vm_fbclient} -- ls -l $nfsmp2/testfile
vm exec -v ${vm_fbclient} -- cat $nfsmp2/testfile

vm exec -v ${vm_mds} -- ls -l $expdir0/testfile
vm exec -v ${vm_mds} -- cat $expdir0/testfile
vm exec -v ${vm_mds} -- pnfsdsfile $expdir0/testfile

vm exec -v ${vm_mds} -- ls -l $expdir1/testfile
vm exec -v ${vm_mds} -- cat $expdir1/testfile
vm exec -v ${vm_mds} -- pnfsdsfile $expdir1/testfile

#mount test from linux Guest
nfsver=4.1
nfsver=4.2
echo
vm port-available -w ${clientvm}
echo -e "{INFO} waiting vm ${clientvm} create process finished ..."
while ps axf|grep -q tmux.new.*$$-$USER.*-d./usr/bin/vm.creat[e].*-n.${clientvm}; do sleep 16; done
echo -e "{INFO} test from ${clientvm}:"
vm exec -vx $clientvm -- showmount -e $mdsaddr
vm exec -vx $clientvm -- mkdir -p $nfsmp
vm exec -vx $clientvm -- mount -t nfs -o nfsvers=$nfsver $mdsaddr:$expdir0 $nfsmp
vm exec -vx $clientvm -- mount -t nfs4
vm exec -vx $clientvm -- bash -c "echo 'hello pnfs' >$nfsmp/hello-pnfs.txt"
vm exec -vx $clientvm -- ls -l $nfsmp
vm exec -vx $clientvm -- cat $nfsmp/hello-pnfs.txt
vm exec -vx $clientvm -- cat $nfsmp/testfile
vm exec -vx $clientvm -- umount $nfsmp
