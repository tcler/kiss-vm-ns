#!/bin/bash

repoUrl=$1
repoPath=$2
if ! { command -v yum &>/dev/null || command -v dnf &>/dev/null; }; then
	echo "{WARN} OS is not supported."
	exit 1
fi
if [[ -z "$repoPath" ]]; then
	echo "Usage: $0 <repo_url> <repo_path> [\$basearch]"
	exit 1
fi

verx=$(rpm -E %rhel)
[[ "$verx" != %rhel && "$verx" -le 7 ]] && {
	echo "{WARN} I am not support RHEL-7 and before"
	exit 1
}

mkdir -p "$repoPath" || exit 2

_curl_download() {
	local url=$1 ourl= curlOOpt=-O
	[[ $url = *%2F* ]] && curlOOpt="-o ${url##*%2F}"
	curl -L -k $url $curlOOpt || {
		ourl=$url
		url=$(curl -Ls -o /dev/null -w %{url_effective} $ourl)
		if [[ "$url" != "$ourl" ]]; then
			curl -L -k $url $curlOOpt
		fi
	}
}
batch_download() {
	if command -v wget2 &>/dev/null; then
		cat | xargs wget2
		return $?
	fi

	while read url; do
		echo "_curl_download $url &"
		_curl_download $url &
	done
	wait
}

pushd "${repoPath}"
reponame=repo$RANDOM
urls=$(yum download --url --disablerepo=* --repofrompath=$reponame,$repoUrl \*|grep '\.rpm$')
time batch_download -p <<<"${urls}"
createrepo .
popd
