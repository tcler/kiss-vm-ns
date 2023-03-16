#!/bin/bash
# kinit non interactive

_kinit() {
	local user=$1
	local pass=$2
	#for macOS
	if kinit -h 2>&1 | grep -q password-file=; then
		kinit_opt=--password-file=STDIN
	fi
	echo $pass | kinit $kinit_opt $user
}

[[ $# -lt 2 ]] && { echo "Usage: $0 <user> <password>" >&2; exit 22; }
_kinit "$@"
