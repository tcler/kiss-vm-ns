#!/bin/bash

fastesturl() {
	local minavg=
	local fast=

	for url; do
		read p host path <<<"${url//\// }";
		cavg=$(ping -w 4 -c 2 $host | awk -F / 'END {print $5}')
		: ${minavg:=$cavg}
		fast=${fast:-$url}

		if [[ -z "$cavg" ]]; then
			echo -e " -> $host\t 100% packet loss." >&2
			continue
		else
			echo -e " -> $host\t $cavg  \t$minavg" >&2
		fi

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
