#!/usr/bin/env bash
#

wget_download_directory() {
	local url=$1
	shift 1;
	local dirs=1
	#https://stackoverflow.com/questions/3074288/get-final-url-after-curl-is-redirected
	url=$(curl -Ls -o /dev/null -w %{url_effective} $url)
	dirs=$(awk '{print length(gensub(/[^\/]/,"","g"))-3}' <<<"${url%/}")
	wget --recursive --no-parent -nH --cut-dirs=$dirs -R "index.html*" $url
}

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
[[ "$#" < 1 ]] && {
	echo "Usage: $0 <url> [more wget options]" >&2
	exit 1
}
wget_download_directory "$@"
