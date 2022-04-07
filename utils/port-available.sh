#!/bin/bash

port_available() {
	if grep -q -- '-z\>' < <(nc -h 2>&1); then
		nc -z $1 $2 </dev/null &>/dev/null
	elif command -v nmap >/dev/null; then
		nmap $1 -p $2 | grep -q open
	else
		timeout 0.1 curl -s -v telnet://$1:$2 |& grep -q ^..Connected
	fi
}

port_available "$@"
