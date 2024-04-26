#!/bin/bash

if [[ $# = 0 ]]; then
	echo "Usage: $0 <hostname|ipaddr> [port] [--wait|-w[=retry]] [-v]" >&2
	exit 1
fi

WTIME=0
_at=()
for arg; do
	case "$arg" in
	(--w*|-w*) WAIT=yes; [[ "$arg" = *=* ]] && WTIME=${arg//[^0-9]/};;
	(--v*|-v*) VERBOSE=yes;;
	(*) _at+=($arg);;
	esac
	shift
done
[[ ${#_at[@]} -lt 2 ]] && _at+=(22)
set -- "${_at[@]}"

port_available() {
	local rc=1
	if grep -q -- '-z\>' < <(nc -h 2>&1); then
		nc -z $1 $2 </dev/null &>/dev/null
	elif command -v nmap >/dev/null; then
		nmap -Pn $1 -p $2 | grep -q open
	else
		timeout 0.1 curl -s -v telnet://$1:$2 |& grep -q ^..Connected
	fi
	rc=$?
	return $rc
}

rc=1
if [[ "$WAIT" != yes ]]; then
	port_available "${@}"; rc=$?
else
	WTIME=${WTIME:-0}
	CNT=$(((WTIME+10)/10))
	T=$WTIME; [[ "$T" = 0 ]] && T=forever
	echo "{INFO} waiting port $1:$2 available, max time(${T}), CNT($CNT)"
	for ((i=0; i<CNT; i++)); do
		port_available "${@}"; rc=$?
		[[ $rc = 0 ]] && break
		[[ "$WTIME" = 0 ]] && { i=0; CNT=2; }
		sleep 10
	done
fi
[[ -n "$VERBOSE" ]] && {
	[[ $rc != 0 ]] && NOT="*NOT* "
	echo -e "{info} port $1:$2 is ${NOT}available"
}
exit $rc
