#!/bin/bash

fastesturl() {
	local minavg=
	local fast=
	local ipv4Opt=
	ping -h |& grep -q '^ *-4' && ipv4Opt=-4

	for url; do
		if curl -L -s --head --request GET ${url} | grep -q "404 Not Found"; then
			echo "[ERROR] return 404 while access: ${url}" >&2
			continue
		fi
		read p host path <<<"${url//\// }";
		cavg=$(ping $ipv4Opt -w 4 -c 2 $host | awk -F / 'END {print $5}')
		: ${minavg:=$cavg}

		if [[ -z "$cavg" ]]; then
			echo -e " -> $host\t 100% packet loss." >&2
			continue
		else
			echo -e " -> $host\t $cavg  \t$minavg" >&2
		fi

		fast=${fast:-$url}
		if awk "BEGIN{exit !($cavg<$minavg)}"; then
			minavg=$cavg
			fast=$url
		fi
	done

	echo $fast
}

[[ $# = 0 ]] && {
	echo "Usage: $0 <url list>" >&2
	exit 1
}

fastesturl "$@"
