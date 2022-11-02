#!/bin/bash

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -x $0 ]] || SH=$SHELL
	#[[ $# -eq 0 ]] && set -- "${BASH_ARGV[@]}" #need enable extdebug: shopt -s extdebug
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}

getReusableCommandLine() {
	#if only one parameter, treat it as a piece of script
	[[ $# = 1 ]] && { echo "$1"; return; }

	local shpattern='^[][0-9a-zA-Z~@%^_+=:,./-]+$'

	for at; do
		if [[ -z "$at" ]]; then
			echo -n "'' "
		elif [[ "$at" =~ $shpattern ]]; then
			echo -n "$at "
		elif [[ "$at" =~ [^[:print:]]+ ]]; then
			echo -n "$(builtin printf %q "$at") "
		else
			echo -n "$at" | sed -r -e ':a;$!{N;ba};' \
				-e "s/'+/'\"&\"'/g" -e "s/^/'/" -e "s/$/' /" \
				-e "s/^''//" -e "s/'' $/ /"
		fi
	done
	echo
}

LOGPATH=${LOGPATH:-.}
run() {
	#ref: https://superuser.com/questions/927544/run-command-in-detached-tmux-session-and-log-console-output-to-file
	local _runtype= _debug= _rc=0
	local _nohup= _nohuplogf=
	local _user= _SUDO=
	local _defaultlogf=${LOGPATH:-.}/nohup.log
	local _tmuxSession= _tmuxlogf=

	while true; do
		case "$1" in
		-debug) _debug=yes; shift;;
		-eval*) _runtype=eval; shift;;
		-bash*) _runtype=bash; shift;;
		-tmux*) _runtype=tmux;
			[[ $1 = *=* ]] && _tmuxSession=${1#*=}
			_tmuxSession=${_tmuxSession:-$$-${USER}}
			_tmuxlogf=${LOGPATH:-/tmp}/run-tmux-${_tmuxSession}.log
			shift;;
		-nohu*) _nohup=yes
			[[ $1 = *=* ]] && _nohuplogf=${1#*=}
			_nohuplogf=${_nohuplogf:-$_defaultlogf}
			shift;;
		-as=*)  _U=${1#*=}; [[ "$_U" = "$USER" ]] || _SUDO="sudo -u $_U"; shift;;
		-*)     shift;;
		*)      break;;
		esac
	done

	[[ $# -eq 0 ]] && return 0
	[[ $# -eq 1 && -z "$_runtype" ]] && _runtype=eval
	[[ "${_runtype}" = eval && -n "$_SUDO" ]] && _SUDO+=\ -s
	local _cmdl=$(getReusableCommandLine "$@")

	if [[ "$_debug" = yes ]]; then
		if [[ "${_runtype}" = tmux ]]; then
			_cmdl="tmux new -s $_tmuxSession -d '$_cmdl' \\; pipe-pane 'cat >$_tmuxlogf'"
		elif [[ "$_nohup" = yes ]]; then
			_cmdl="nohup $_cmdl &>${_nohuplogf} &"
		fi
		echo "[${_runtype:-direct} run]" "$_SUDO $_cmdl"
	fi | GREP_COLORS='ms=0;33;44' grep --color .

	case ${_runtype:-direct} in
	direct)
		if [[ -n "$_nohup" ]]; then
			$_SUDO touch "${_nohuplogf}"
			$_SUDO nohup "$@" &>${_nohuplogf} &
		else
			$_SUDO "$@"; _rc=$?
		fi
		;;
	eval)   $_SUDO eval "$_cmdl"; _rc=$?;;
	bash)   $_SUDO bash -c "$_cmdl"; _rc=$?;;
	tmux)   $_SUDO tmux new -s $_tmuxSession -d "$_cmdl" \; pipe-pane "cat >$_tmuxlogf"; _rc=$?;;
	esac

	return $_rc
}

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
switchroot "$@"
run -debug  ls --color=always /root
