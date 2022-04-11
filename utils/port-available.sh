#!/bin/bash

_at=()
for arg; do
	case "$arg" in
	(--w*|-w*) WAIT=yes; [[ "$arg" = *=* ]] && TIME=${arg/*=/};;
	(*) _at+=($arg);;
	esac
	shift
done

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
	port_available "${_at[@]}"; rc=$?
else
	TIME=${TIME//[^0-9]/}
	TIME=${TIME:-0}
	CNT=$(((TIME+10)/10))
	T=$TIME; [[ "$T" = 0 ]] && T=forever
	echo "[INFO] waiting port ${_at[@]} available, max time(${T}), CNT($CNT)"
	for ((i=0; i<CNT; i++)); do
		port_available "${_at[@]}"; rc=$?
		[[ $rc = 0 ]] && break
		[[ "$TIME" = 0 ]] && { i=0; CNT=2; }
		sleep 10
	done
fi
exit $rc
