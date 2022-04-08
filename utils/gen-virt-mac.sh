#!/bin/bash

# Generate a random mac address with 54:52:00: prefix
gen_virt_mac() {
	echo 54:52:00:${1:-00}$(od -txC -An -N2 /dev/random | tr \  :)
}

gen_virt_mac "$@"
