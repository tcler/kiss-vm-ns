#!/bin/bash

Cleanup() {
	rm -f $stdlogf
	exit
}
trap Cleanup EXIT #SIGINT SIGQUIT SIGTERM

distro=$1
imagef=$2

distro=${distro:-CentOS-8}
if [[ ! -f "$imagef" ]]; then
	stdlogf=/tmp/std-$$.log
	echo -e "\n{INFO} downloading qcow2 image of $distro ..."
	vm --downloadonly $distro 2>&1 | tee $stdlogf
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
	echo -e "\n{INFO} download image file done:"
fi
echo -e "\e[4m$(ls -l $imagef)\e[0m"

#__main__
echo -e "\n{INFO} creating virtual network ..."
vm net netname=student brname=virbr-student subnet=172.25.250.0 forward=no 
vm net netname=classroom brname=virbr-classroom subnet=172.25.252.0 forward=no 

echo -e "\n{INFO} remove existing VMs ..."
vmlist="workstation servera serverb utility bastion classroom"
vm del $vmlist >/dev/null

echo -e "\n{INFO} creating VMs ..."
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net student -n workstation"
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net student -n servera"
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net student -n serverb"
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net student -n utility"
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net classroom --net student -n bastion"
tmux new -d "/usr/bin/vm create -f $distro -i $imagef --nointeract --net classroom --net-macvtap -n classroom"

port_available() { nc $(grep -q -- '-z\>' < <(nc -h 2>&1) && echo -z) $1 $2 </dev/null &>/dev/null; }
for _vm in $vmlist; do
	echo -e "\n{INFO} waiting VM($_vm) install finish ..."
	until port_available $_vm 22; do sleep 2; done
done

serveraAddr=$(vm if servera)
classroomAddr=$(vm if classroom)
bastionIpAddrs=$(vm exec bastion -- ip a)
read bastionAddr252 _ < <(echo "$bastionIpAddrs" | awk -F'[ /]+' '/ *inet 172.25.252/{printf $3 " "}')
read bastionAddr250 _ < <(echo "$bastionIpAddrs" | awk -F'[ /]+' '/ *inet 172.25.250/{printf $3 " "}')

#check default setup of net.ipv4.ip_forward and net.ipv4.conf.all.forwarding
vm exec -v bastion -- sysctl net.ipv4.ip_forward \#check default ipv4.ip_forward setup
vm exec -v bastion -- sysctl net.ipv4.conf.all.forwarding \#check default ipv4.conf.all.forwarding setup

#enable ip forward on bastion
#vm exec -v bastion -- sysctl -w net.ipv4.conf.all.forwarding=1
vm exec -v bastion -- sysctl -w net.ipv4.ip_forward=1

#setup route table
vm exec -v classroom -- ip route add 172.25.250.0/24 via $bastionAddr252
_vmlist="workstation servera serverb utility"
for _vm in $_vmlist; do
	vm exec -v $_vm -- ip route add 172.25.252.0/24 via $bastionAddr250
done

#check route table
vm exec -v servera -- ip route s
vm exec -v classroom -- ip route s

#ping test
vm exec -v bastion -- sysctl net.ipv4.ip_forward \#check ipv4.ip_forward setup
vm exec -v bastion -- sysctl net.ipv4.conf.all.forwarding \#check ipv4.conf.all.forwarding setup
vm exec -v servera -- ping -c 2 $bastionAddr252   \#ping router bastion addr1
vm exec -v servera -- ping -c 2 $bastionAddr250   \#ping router bastion addr2
vm exec -v classroom -- ping -c 2 $bastionAddr252 \#ping router bastion addr1
vm exec -v classroom -- ping -c 2 $bastionAddr250 \#ping router bastion addr2
vm exec -v servera -- ping -c 3 $classroomAddr  \#ping classroom
vm exec -v classroom -- ping -c 3 $serveraAddr  \#ping servera

#TBD: ...
