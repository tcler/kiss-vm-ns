#!/bin/bash

port_available() {
	if grep -q -- '-z\>' < <(nc -h 2>&1); then
		nc -z $1 $2 </dev/null &>/dev/null
	else
		nmap $1 -p $2 | grep -q open
	fi
}

port_available "$@"
