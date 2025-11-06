#!/bin/bash

[[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && exec sudo $0 "$@"

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
	if [[ ${#downvpns[@]} -eq 0 ]]; then
		echo "{warn} did not find vpn connection by using: nmcli c s" >&2
		exit 1
	elif [[ ${#downvpns[@]} -eq 1 ]]; then
		echo "{exec} nmcli connection --ask up '${downvpns}'"
		nmcli connection --ask up "${downvpns}"
		exit
	fi

	select vpn in /quit "${downvpns[@]}"; do
		[[ -z "${vpn}" || ${vpn} = /q* ]] && break
		echo "{info} up the vpn(${vpn}) you selected ..."
		echo "{exec} nmcli connection --ask up '${vpn}'"
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

	select vpn in /quit "${upvpns[@]}"; do
		[[ -z "${vpn}" || ${vpn} = /q* ]] && break
		echo "{info} up the vpn(${vpn}) you selected ..."
		echo "{exec} nmcli connection --ask up '${vpn}'"
		nmcli connection --ask up "${vpn}" && {
			nmcli c s | grep -F "${vpn}"
			break
		}
	done
fi
