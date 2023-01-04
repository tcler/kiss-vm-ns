#!/bin/bash

repoUrl=$1
reponame=repo$RANDOM
if ! { command -v yum &>/dev/null || command -v dnf &>/dev/null; }; then
	echo "{WARN} OS is not supported."
	exit 1
fi
if [[ -z "$repoUrl" ]]; then
	echo "Usage: $0 <repo_url>"
	exit 1
fi

verx=$(rpm -E %rhel)
[[ "$verx" != %rhel && "$verx" -le 7 ]] && yum install -y yum-utils &>/dev/null
: <<\COMMENT
if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
	#yumdownloader does not support --repofrompath= option,sh*t
	repof=/etc/yum.repos.d/${reponame}.repo
	cat <<-REPO >$repof
	[$reponame]
	name=$reponame
	baseurl=$repoUrl
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	REPO
	urls=$(yumdownloader --url --disablerepo=* --enablerepo=$reponame \*)
	rm -f $repof
else
	urls=$(yum download --url --disablerepo=* --repofrompath=$reponame,$repoUrl \*)
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
