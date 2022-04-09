#!/bin/bash

# Generate a random mac address with 54:52:00: prefix
gen_virt_mac() {
	#echo -n 54:52:00:${1:-00}$(od -txC -An -N2 /dev/random | tr \  :)
	echo -n 54:52:00$(od -txC -An -N3 /dev/random | tr \  :)
}

num=${1//[^0-9]/}
num=${num:-1}
macpoll=()
for ((i=0; i<${num}; i++)); do
	macpoll[$i]=$(gen_virt_mac)
done
echo ${macpoll[@]}
