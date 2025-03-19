# !/bin/bash
# Thanks Patryk Obara:
#   https://stackoverflow.com/a/45977232
#   https://stackoverflow.com/questions/6174220/parse-url-in-shell-script/45977232#45977232
# Following regex is based on https://www.rfc-editor.org/rfc/rfc3986#appendix-B with
# additional sub-expressions to split authority into userinfo, host and port
#
readonly URI_REGEX='^(([^:/?#]+):)?(//((([^:/?#]+)@)?([^:/?#]+)(:([0-9]+))?))?(/([^?#]*))(\?([^#]*))?(#(.*))?'
#                    ↑↑            ↑  ↑↑↑            ↑         ↑ ↑            ↑ ↑        ↑  ↑        ↑ ↑
#                    |2 scheme     |  ||6 userinfo   7 host    | 9 port       | 11 rpath |  13 query | 15 fragment
#                    1 scheme:     |  |5 userinfo@             8 :…           10 path    12 ?…       14 #…
#                                  |  4 authority
#                                  3 //…

parse_uri () {
	local rc=0
	declare -A uri
	if [[ "$@" =~ $URI_REGEX ]]; then
		#uri[authority]=${BASH_REMATCH[4]}
		uri[proto]=${BASH_REMATCH[2]}
		uri[user]=${BASH_REMATCH[6]}
		uri[host]=${BASH_REMATCH[7]}
		uri[port]=${BASH_REMATCH[9]}
		uri[path]=${BASH_REMATCH[10]}
		uri[rpath]=${BASH_REMATCH[11]}
		uri[query]=${BASH_REMATCH[13]}
		uri[fragment]=${BASH_REMATCH[15]}
		for key in "${!uri[@]}"; do
			echo "$key: ${uri[$key]}"
		done
	else
		echo "'$1' is not a valid url" >&2
		rc=1
	fi
	return $rc
}

parse_uri "$1"
