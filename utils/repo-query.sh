#!/bin/bash

repoUrl=$1
reponame=repo$RANDOM
verx=$(rpm -E %rhel)

: <<\COMMENT
if [[ "$verx" -le 7 ]]; then
	urls=$(yumdownloader --url --disablerepo=* --enablerepo=$reponame \*)
else
	urls=$(yum download --url --disablerepo=* --repofrompath=$repopath \*)
fi
COMMENT

stderrf=/tmp/stderr-$$.log
trap 'rm -f ${stderrf}' EXIT
if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
	repoquery -a --repoid=$reponame --repofrompath=$reponame,$repoUrl
else
	yum --disablerepo=* --repofrompath=$reponame,$repoUrl  rq $reponame \*
fi 2>$stderrf
stderr=$(< $stderrf); rm $stderrf

if grep -q Error <<<"$stderr"; then
	echo "$stderr" >&2
	echo -e "\033[31m{error} the repo url is invalid or unaccessable:\n  \033[4m$repoUrl\033[0m" >&2
	exit 2
fi
