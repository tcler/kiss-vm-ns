#!/bin/bash

nfstestFailChk() {
	local rc=0
	local exnfail=$1 npass= nfail=
	local testlog=$2
	if [[ ! -r ${testlog} ]]; then
		echo -e "\E[1;31m{nfstest fail check} test log file(${testlog}) not accessable/exist.\E[0m"
		return 2
	fi
	read _ npass nfail < <(awk -F'[ ()]+' '/^[0-9]+ tests /{print $1,$3,$5}' $testlog)
	if [[ ${nfail} -gt ${exnfail} ]]; then
		echo -e "\E[1;31m{nfstest fail check} fail number(${nfail}) is great than expected(${exnfail})\E[0m"
		rc=1
	fi
	return $rc
}

nfstestFailChk "$@"
