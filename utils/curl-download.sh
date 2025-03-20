#!/usr/bin/env bash
#

curl_download() {
	local filename=$1
	local url=$2
	shift 2;
	[[ -n "$1" && "$1" = timeo=* ]] && shift 1

	local curlopts="-f -L -k"
	local header=
	local fsizer=1
	local fsizel=0
	local rc=

	[[ -z "$filename" || -z "$url" ]] && {
		echo "Usage: curl_download <path/to[/filename]> <url> [curl options]" >&2
		return 1
	}

	if [[ -d "$filename" ]]; then
		read uri urlparam <<<"${url/\?/ }"
		ofname=${uri%%#*}
		ofname=${ofname##*/}
		filename=${filename%/}/${ofname}
	fi

	header=$(curl -Lks -I $url|sed 's/\r//')
	fsizer=$(echo "$header"|awk -v IGNORECASE=1 '/Content-Length:/ {print $2; exit}')
	if echo "$header"|grep -iq 'Accept-Ranges: bytes'; then
		curlopts+=' --continue-at -'
	fi

	echo "{INFO} run: curl -o $filename \$url $curlopts $curlOpt $@"
	curl -o $filename $url $curlopts $curlOpt "$@"
	rc=$?
	if [[ $rc != 0 && -s $filename ]]; then
		fsizel=$(stat --printf %s $filename)
		if [[ $fsizer -le $fsizel ]]; then
			echo "{VM:INFO} *** '$filename' already exist $fsizel/$fsizer"
			rc=0
		fi
	fi

	return $rc
}
curl_download_x() {
	echo "{INFO} url=$2";
	local loop=1;
	until curl_download "$@"; do
		sleep 1; let loop++;
		test -n "$RETRY" && ((loop > $RETRY)) && break
	done
}

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
[[ "$#" < 2 ]] && {
	echo "Usage: $0 [-otimeo=\$time,retry=\$N] <path/to[/filename]> <url> [curl options]" >&2
	exit 1
}

if [[ "$1" = -o* ]]; then
	opts=${1#-o}; shift 1
	for opt in ${opts//,/ }; do case $opt in (retry=*|timeo=*) eval ${opt^^};; esac; done
fi

if [[ -n "$timeo" ]]; then
	exec timeout $TIMEO $0 -oretry=$RETRY "$@"
else
	curl_download_x "$@"
fi
