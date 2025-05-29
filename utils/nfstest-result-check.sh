#!/bin/bash

nfstestFailChk() {
	local rc=0
	local exnfail=$1 npass= nfail=
	local testlog=$2
	read _ npass nfail < <(awk -F'[ ()]+' '/^[0-9]+ tests /{print $1,$3,$5}' $testlog)
	if [[ ${nfail} -gt ${exfail} ]]; then
		echo -e "\E[1;31m{nfstest fail check} fail number(${nfail}) is great than expected(${exnfail})\E[0m"
		rc=1
	fi
	return $rc
}

nfstestFailChk "$@"
