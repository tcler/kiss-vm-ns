#!/bin/bash
#

vncput() {
	local vncserv=$1
	shift

	[[ -z "$vncserv" || ${#} -lt 1 ]] && {
		echo -e "Usage:\n  $0 <vncserver:port> <strings|key-strings> [strings|key-strings ...]" >&2
		cat <<-EOF
			Example:
			  $0 vncserver:5901 "systemctl enable sshd" key:enter
			  $0 vncserver:5902 key:tab key:enter redhat key:enter key:sleep:8 key:esc key:alt-f2 gnome-terminal key:enter
			  $0 vncserver:5902 key:ctrl-alt-f1
			  $0 vncserver:5903 keyup:any-string
			  $0 vncserver:5903 keydown:any-string
		EOF
		return 1
	}
	[[ "$vncserv" != *::* && "$vncserv" = *:* ]] && vncserv=${vncserv/:/::}

	command -v vncdo >/dev/null || {
		echo -e "{VNCPUT:WARN} command vncdo is required! please try:\n    pip install vncdotool" >&2
		return 1
	}

	local msgArray=()
	for msg; do
		[[ -z "$msg" ]] && { msgArray+=(); continue; }
		case "$msg" in
		key:*|keyup:*|keydown:*)
			msgArray+=("$msg")
			;;
		*)
			regex='[~@#$%^&*()_+|}{":?><!]'
			_msg="${msg#type:}"
			if [[ "$_msg" =~ $regex ]]; then
				while IFS= read -r line; do
					line="type:$line"
					msgArray+=("$line")
				done < <(sed -r -e 's;[~!@#$%^&*()_+|}{":?><]+;&\n;g' -e 's;[~!@#$%^&*()_+|}{":?><];\nkey:shift-&;g' <<<"$_msg")
			else
				msgArray+=("$msg")
			fi
			;;
		esac
		msgArray+=("")
	done
	for msg in "${msgArray[@]}"; do
		[[ -z "${msg}" ]] && { sleep 0.5; continue; }
		[[ "${msg}" = key:sleep:* ]] && { sleep ${msg#key:sleep:}; continue; }
		case "$msg" in
		key:*)     vncdo --force-caps -s $vncserv key "${msg#key:}";;
		keyup:*)   vncdo --force-caps -s $vncserv keyup "${msg#keyup:}";;
		keydown:*) vncdo --force-caps -s $vncserv keydown "${msg#keydown:}";;
		*)         vncdo --force-caps -s $vncserv type "${msg#type:}";;
		esac
	done
}

vncput "${@}"
