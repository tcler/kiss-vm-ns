#!/bin/bash
# just for fun, and ease my vpn connect

[[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && exec sudo $0 "$@"

askuser() {
	local nmc="${*}"
	local u=$(nmcli -g vpn.user-name c s "${nmc}")
	local iuser=
	while [[ -z "$iuser" ]]; do
		read -p "Enter username([$u]): " iuser
		if [[ -n "$iuser" ]]; then
			[[ "$iuser" != "$u" ]] &&
				nmcli c modify "${nmc}" vpn.user-name $iuser
		elif [[ -n "$u" ]]; then
			iuser=$u
		else
			echo "{warn} vpn.user-name is empty" >&2
		fi
	done
}

downvpns=()
upvpns=()
while read stat vpn; do
	[[ $stat = up ]] && upvpns+=("${vpn}") || downvpns+=("${vpn}");
done < <(nmcli connection show | awk '
	$(NF-1) == "vpn" {
		stat = "up"; if ($NF == "--") stat = "down";
		for (i=NF; i>NF-3; i--) { $i=""; }
		print stat, $0
	}')

if [[ $1 != d* ]]; then
	if [[ ${#upvpns} -ne 0 ]]; then
		echo "{warn} there is vpn already connected" >&2
		nmcli connection show | awk '$(NF-1) == "vpn" && $NF != "--"'
	fi

	if [[ ${#downvpns[@]} -eq 0 ]]; then
		echo "{warn} did not find vpn connection by using: nmcli c s" >&2
		exit 1
	elif [[ ${#downvpns[@]} -eq 1 ]]; then
		echo "{exec} nmcli connection --ask up '${downvpns}'"
		askuser "${downvpns}"
		nmcli connection --ask up "${downvpns}"
		exit
	fi

	select vpn in "${downvpns[@]}"; do
		[[ -z "${vpn}" || ${vpn} = /q* ]] && break
		echo "{info} up/connect the vpn(${vpn}) you selected ..."
		echo "{exec} nmcli connection --ask up '${vpn}'"
		askuser "${vpn}"
		nmcli connection --ask up "${vpn}" && {
			nmcli c s | grep -F "${vpn}"
			break
		}
	done
else
	if [[ ${#upvpns[@]} -eq 0 ]]; then
		echo "{warn} did not find *up* vpn connection by using: nmcli c s" >&2
		exit 1
	elif [[ ${#upvpns[@]} -eq 1 ]]; then
		echo "{exec} nmcli connection down '${upvpns}'"
		nmcli connection down "${upvpns}"
		exit
	fi

	select vpn in "${upvpns[@]}"; do
		[[ -z "${vpn}" || ${vpn} = /q* ]] && break
		echo "{info} down/disconnect the vpn(${vpn}) you selected ..."
		echo "{exec} nmcli connection down '${vpn}'"
		nmcli connection down "${vpn}"
		break
	done
fi
