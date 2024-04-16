#!/usr/bin/env bash
#

IPCALC=ipcalc; command -v ipcalc-ng &>/dev/null && IPCALC=ipcalc-ng
command -v expect &>/dev/null || {
	echo "{error} command 'expect' is required, but not found; please install expect first." >&2
	exit 2
}

host=$1
user=$2
password=$3
[[ $# -lt 3 ]] && {
	echo "Usage: $0 <host-address> <user> <passwd>" >&2
	exit 1
}
shift 3

$IPCALC -cs $host || {
	read hostaddr _ < <(vm if "$host" 2>/dev/null || getent hosts "$host"|awk '{print $1}')
	$IPCALC -cs $hostaddr && host=$hostaddr
}

test -f ~/.ssh/id_ecdsa || {
	ssh-keygen -q -t ecdsa -f ~/.ssh/id_ecdsa -N ''
}
expect -c "log_user 1; set timeout 15
	spawn ssh-copy-id -o StrictHostKeyChecking=no -f $@ $user@$host
	log_user 0
	expect -re {.*assword:|[Pp]assword.for.*:} {send \"$password\\n\"}
	lassign [wait] pid spawnid osrc rc
	exit $rc
"
