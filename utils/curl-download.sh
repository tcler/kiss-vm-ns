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
		filename=${filename%/}/${url##*/}
	fi

	header=$(curl -L -I -s $url|sed 's/\r//')
	fsizer=$(echo "$header"|awk '/Content-Length:/ {print $2; exit}')
	if echo "$header"|grep -q 'Accept-Ranges: bytes'; then
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
curl_download_x() { echo "{INFO} url=$2"; until curl_download "$@"; do sleep 1; done; }

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
[[ "$#" < 2 ]] && {
	echo "Usage: $0 <path/to[/filename]> <url> [timeo=<time>] [curl options]" >&2
	exit 1
}

[[ "$3" = timeo=* ]] && timeout=${3#timeo=}
if [[ -n "$timeout" ]]; then
	file=$1; url=$2; shift 3
	exec timeout $timeout $0 "$file" "$url" "$@"
else
	curl_download_x "$@"
fi
