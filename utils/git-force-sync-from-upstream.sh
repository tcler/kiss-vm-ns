#!/bin/bash

forceSyncFromUpstream() {
	local uprepo=$1 ouprepo nuprepo
	#local master=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
	local master=$(git branch | grep -o -m1 "\b\(master\|main\)\b")

	ouprepo=$(git remote -v | awk '$1 == "upstream" {print $2; exit}')
	if [[ -n "$ouprepo" && -n "$uprepo" && "$orepo" != "$uprepo" ]]; then
		git remote set-url upstream "$uprepo"
	elif [[ -z "$ouprepo" && -n "$uprepo" ]]; then
		git remote add upstream $uprepo
	fi
	nuprepo=$(git remote -v | awk '$1 == "upstream" {print $2; exit}')
	if [[ -n "$nuprepo" ]]; then
		echo "{Info} force sync from upstream repo: ${nuprepo} ..."
	else
		echo "{Error} there is not 'upstream' setup in your git config" >&2
		exit 2
	fi

	git fetch upstream
	git checkout ${master}
	git reset --hard upstream/${master}  
	git push origin ${master} --force
}

repofrom=$1
forceSyncFromUpstream $repofrom
if [[ $? = 2 ]]; then
	cat <<-EOF
	Usage: $0 <upstream-repo-url>
	#Note: if you have not setup upstream in your git config, a parameter 'upstream-repo-url' is required
	EOF
fi
