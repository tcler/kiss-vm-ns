#!/bin/bash
#ref:
# - https://people.freebsd.org/~rmacklem/pnfs-planb-setup.txt
# - FreeBSD pnfsserver(4) man-page

. /usr/lib/bash/libtest || { echo "{ERROR} 'kiss-vm-ns' is required, please install it first" >&2; exit 2; }
PROG=$0; ARGS=("$@")

Usage() {
	cat <<-EOF
	Usage:
	  $PROG [9|10|CentOS-10-stream|RHEL-10.2-20251217.0 [--clientvm=<vmname>]] [-- vm-create-options]
	EOF
}
_at=$(getopt -a -o h \
	--long help \
	--long clientvm: \
	-n "$PROG" -- "$@")
[[ $? != 0 ]] && { Usage >&2; exit 1; }
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	--clientvm) clientvm=$2; shift 2;;
	--) shift; break;;
	esac
done
[[ $# -gt 0 ]] && { distro=$1; shift; }
case $distro in (h|he|hel|help|\?) Usage; exit 1;; esac

[[ -z "$distro" && -n "$clientvm" ]] && { Usage >&2; exit 1; }

#create freebsd VMs
#-------------------------------------------------------------------------------
freebsd_nvr=FreeBSD-${FREEBSD_VERS:-14.3}
nfs4minver=2
vm_ds0=freebsd-pnfs-ds0
vm_ds1=freebsd-pnfs-ds1
vm_ds2=freebsd-pnfs-ds2
vm_ds3=freebsd-pnfs-ds3
vm_mds=freebsd-pnfs-mds
vm_fbclient=freebsd-pnfs-client

pkgs=nfs-utils,expect,iproute-tc,kernel-modules-extra,vim,bind-utils,tcpdump,tmux,fio

stdlogf=/tmp/std-$$.log
vm create --downloadonly $freebsd_nvr --saveimage 2>&1 | tee $stdlogf
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
vm delete ${vm_ds0%0}* ${vm_mds} ${vm_fbclient}

echo -e "\n{INFO} creating VMs ..."
#the option --if-model=e1000 is a workaround for FreeBSD VM issue on Fedora-41 host
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds0 -dsize 80 -f --nointeract --if-model=e1000 "${@}" -i $imagef
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds1 -dsize 80 -f --nointeract --if-model=e1000 "${@}" -i $imagef
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds2 -dsize 80 -f --nointeract --if-model=e1000 "${@}" -i $imagef
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_ds3 -dsize 80 -f --nointeract --if-model=e1000 "${@}" -i $imagef
trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_mds -dsize 40 -f --nointeract --if-model=e1000 "${@}" -i $imagef
if [[ -z "$distro" ]]; then
	trun       /usr/bin/vm create $freebsd_nvr -n $vm_fbclient -f --nointeract --if-model=e1000 "${@}" -i $imagef
else
	trun -tmux /usr/bin/vm create $freebsd_nvr -n $vm_fbclient -f --nointeract --if-model=e1000 "${@}" -i $imagef
	clientvm=${clientvm:-fbpnfs-linux-client}
	trun       /usr/bin/vm create $distro -n $clientvm -p $pkgs --saveimage -f --nointeract "${@}"
fi

echo -e "\n{INFO} waiting VMs install finish ..."
#config freebsd pnfs ds server
for dsserver in $vm_ds0 $vm_ds1 $vm_ds2 $vm_ds3; do
	vm port-available -w ${dsserver}
	echo -e "\n{INFO} setup ${dsserver}:"
	cpfile=freebsd-pnfs-ds.sh; [[ -f "$cpfile" ]] || cpfile=/usr/bin/$cpfile
	vm cpto    ${dsserver} $cpfile /usr/bin
	vm exec -v ${dsserver} $cpfile
	vm exec -v ${dsserver} -- showmount -e localhost
done

#config freebsd pnfs mds server
echo -e "\n{INFO} setup ${vm_mds}:"
ds0addr=$(vm ifaddr $vm_ds0|head -1)
ds1addr=$(vm ifaddr $vm_ds1|head -1)
ds2addr=$(vm ifaddr $vm_ds2|head -1)
ds3addr=$(vm ifaddr $vm_ds3|head -1)
vm port-available -w ${vm_mds}
vm exec -vx ${vm_mds} -- sh -c "cat <<HOST >>/etc/hosts
$ds0addr $vm_ds0
$ds1addr $vm_ds1
$ds2addr $vm_ds2
$ds3addr $vm_ds3
"
cpfile=freebsd-pnfs-mds.sh; [[ -f "$cpfile" ]] || cpfile=/usr/bin/$cpfile
vm cpto    ${vm_mds} $cpfile /usr/bin
vm exec -vx ${vm_mds} $cpfile $ds0addr $ds1addr $ds2addr $ds3addr
vm exec -vx ${vm_mds} -- mount -t nfs
vm exec -vx ${vm_mds} -- showmount -e localhost
vm exec -v  ${vm_mds} -- grep No.name.and/or.group.mapping.for /var/log/messages

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
vm exec -v ${vm_fbclient} -- sh -c "echo abcdef0123456789 >$nfsmp2/testfile"

vm exec -v ${vm_fbclient} -- ls -l $nfsmp/testfile
vm exec -v ${vm_fbclient} -- cat $nfsmp/testfile

vm exec -v ${vm_fbclient} -- ls -l $nfsmp2/testfile
vm exec -v ${vm_fbclient} -- cat $nfsmp2/testfile

vm exec -v ${vm_mds} -- ls -l $expdir0/testfile
vm exec -v ${vm_mds} -- cat $expdir0/testfile
vm exec -vx ${vm_mds} -- pnfsdsfile $expdir0/testfile

vm exec -v ${vm_mds} -- ls -l $expdir1/testfile
vm exec -v ${vm_mds} -- cat $expdir1/testfile
vm exec -vx ${vm_mds} -- pnfsdsfile $expdir1/testfile

[[ -z "$distro" ]] && {
	exit
}

#mount test from linux Guest
nfsver=4.2
echo
vm port-available -w ${clientvm}
echo -e "{INFO} test from ${clientvm}:"
vm exec -vx $clientvm -- showmount -e $mdsaddr
vm exec -vx $clientvm -- mkdir -p $nfsmp
vm exec -vx $clientvm -- modprobe nfs
vm exec -vx $clientvm -- mount -vvv -onfsvers=$nfsver $mdsaddr:$expdir0 $nfsmp
vm exec -vx $clientvm -- mount -t nfs4
vm exec -vx $clientvm -- bash -c "echo 'hello pnfs' >$nfsmp/hello-pnfs.txt"
vm exec -vx $clientvm -- ls -l $nfsmp
vm exec -vx $clientvm -- cat $nfsmp/hello-pnfs.txt
vm exec -vx $clientvm -- cat $nfsmp/testfile
vm exec -vx $clientvm -- tmux new -d "while :; do dd if=/dev/zero of=$nfsmp/ddtestfile bs=10M count=1024 oflag=direct status=progress; done"
vm exec -vx $clientvm -- tmux new -d "while :; do dd if=/dev/zero of=$nfsmp/ddtestfile1 bs=10M count=1024 oflag=direct status=progress; done"
vm exec -vx $clientvm -- tmux new -d "while :; do dd if=/dev/zero of=$nfsmp/ddtestfile2 bs=10M count=1024 oflag=direct status=progress; done"
vm exec -vx $clientvm -- 'ps auxw | grep -w d[d]'
vm exec -vx $clientvm -- uname -r
vm exec -vx ${vm_mds} -- "pnfsdsfile $expdir0/ddtestfile; pnfsdsfile $expdir0/ddtestfile1; pnfsdsfile $expdir0/ddtestfile2" || exit 2

trun -tmux=console-${clientvm} -logf=/tmp/console-${clientvm}.log vm console ${clientvm}
show-console() {
	trun sed '/\[    0.000000] [^LC]/,$d' /tmp/console-${clientvm}.log;
	tmux kill-session -t console-${clientvm};
}
loop=${loop:-8}
for ((i=0; i<loop; i++)); do
	trun "sleep 32 #$i"
	vm stop freebsd-pnfs-ds*;
	vm port-available ${clientvm} || { echo "{Error} ${clientvm} broken?"; show-console; exit 2; }
	vm start freebsd-pnfs-ds*;
	vm exec -vx ${clientvm} -- 'ps axf | grep -w d[d]' || { echo "{Error} ${clientvm} restarted" >&2; show-console; exit 2; }
done
tmux kill-session -t console-${clientvm}
