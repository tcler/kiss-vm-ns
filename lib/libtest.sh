#!/bin/bash

switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	#[[ $# -eq 0 ]] && set -- "${BASH_ARGV[@]}" #need enable extdebug: shopt -s extdebug
	[[ $(id -u) != 0 ]] && {
		if [[ "${SHELL##*/}" = $P ]]; then
			echo -e "\E[1;31m{WARN} $P need root permission, please add sudo before $P\E[0m" >&2
			exit
		else
			echo -e "\E[1;30m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m" >&2
			exec sudo $SH $P "$@"
		fi
	}
}

_range2list() {
	local range=$1  #like: 1,3,5,11-100,127
	local list=()
	for rc in ${range//,/ }; do
		if [[ "$rc" =~ ^[0-9]+$ ]]; then
			list+=($rc)
		elif [[ "$rc" =~ ^[0-9]+-[0-9]+$ ]]; then
			eval list+=({${rc/-/..}})
		fi
	done
	echo -n ${list[@]}
}
_list_contains() {
	[[ "$1" =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1
}
rc_isexpected() {
	local rc=$1
	local range=$2
	local rangelist=$(_range2list $range)
	_list_contains "$rangelist" $rc
}
chkrc() {
	local xrange=$1; shift
	local comment=
	if [[ $# -eq 0 ]]; then
		comment="return code($_RC), expected range($xrange)"
	else
		comment="$*"
	fi
	if rc_isexpected "$xrange" $_RC; then
		echo -e "\E[1;34m{TEST PASS} $comment\E[0m"
	else
		echo -e "\E[1;31m{TEST FAIL} $comment\E[0m"
	fi
	return $_RC
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

TEST_LOGPATH=${TEST_LOGPATH:-.}
_RC=0
run() {
	#ref: https://superuser.com/questions/927544/run-command-in-detached-tmux-session-and-log-console-output-to-file
	local _runtype= _debug= _rc=0
	local _nohup= _nohuplogf=
	local _user= _SUDO=
	local _default_nohuplogf=${TEST_LOGPATH:-.}/nohup.log
	local _tmuxSession= _tmuxlogf=
	local _xrcrange= _chkrc=no

	while true; do
		case "$1" in
		-d|-debug) _debug=yes; shift;;
		-eval*) _runtype=eval; shift;;
		-bash*) _runtype=bash; shift;;
		-tmux*) _runtype=tmux;
			[[ $1 = *=* ]] && _tmuxSession=${1#*=}
			_tmuxSession=${_tmuxSession:-$$-${USER}}
			_tmuxlogf=${TEST_LOGPATH:-/tmp}/run-tmux-${_tmuxSession}.log
			shift;;
		-nohu*) _nohup=yes
			[[ $1 = *=* ]] && _nohuplogf=${1#*=}
			_nohuplogf=${_nohuplogf:-$_default_nohuplogf}
			shift;;
		-as=*)  _U=${1#*=}; [[ "$_U" = "$USER" ]] || _SUDO="sudo -u $_U"; shift;;
		-x*|-x=*) _chkrc=yes;
			_xrcrange=${1:2}; _xrcrange=${_xrcrange#=}
			[[ -z "$_xrcrange" ]] && _xrcrange=0
			shift;;
		-*)     shift;;
		*)      break;;
		esac
	done

	[[ $# -eq 0 ]] && {
		cat <<-\EOF >&2
		Usage: run [options] command [cmd-opts] [args]
		Examples:
		  run -d 'echo "$exportdir *(rw,no_root_squash)" >/etc/exports'
		  run -d 'var=$(ls)'
		  run -d 'find . -type f | grep ^$path$'
		  run -d systemctl restart nfs-server
		  run -d -as=user -x0 touch /root/file
		  run -d -x0 grep pattern /path/to/file

		  run -d -nohup tail -f /path/to/file
		  run -d -nohup=nohup-log-file tail -f /path/to/file
		  run -d -tmux=sessoin-name tail -f /path/to/file
		EOF
		return 0
	}

	[[ $# -eq 0 ]] && return 0
	[[ $# -eq 1 && -z "$_runtype" ]] && _runtype=eval
	[[ "${_runtype}" = eval && -n "$_SUDO" ]] && _SUDO+=\ -s
	local _cmdl=$(getReusableCommandLine "$@")
	local _cmdlx=

	if [[ "$_debug" = yes ]]; then
		if [[ "${_runtype}" = tmux ]]; then
			_cmdl="tmux new -s $_tmuxSession -d '$_cmdl' \\; pipe-pane 'cat >$_tmuxlogf'"
		elif [[ "$_nohup" = yes ]]; then
			_cmdl="nohup $_cmdl &>${_nohuplogf} &"
		fi
		[[ -n "$_SUDO" ]] && _cmdlx="$_SUDO $_cmdl" || _cmdlx=$_cmdl
		echo -e "[$(date +%T) $USER $PWD]\n\E[0;33;44mrun(${_runtype:-plat})> $_cmdlx\E[0m"
	fi

	case ${_runtype:-plat} in
	plat)
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

	_RC=$_rc
	[[ "$_chkrc" = yes ]] && { chkrc $_xrcrange; }
	return $_rc
}
trun() { run -d "$@"; }

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
echo "[INFO] this is a lib file, run internal test:"
trun -x ls --color=always /root
run switchroot "$@"
trun 'for ((i=0; i<8; i++)); do echo $i; done'
trun 'var=$(ls -l)'
trun 'grep OS /etc/os-release'
	chkrc 1 "there should not be OS string in /etc/os-release"
trun 'grep RHEL /etc/os-release'
	chkrc 0 "there should be RHEL string in /etc/os-release"
trun 'systemctl status nfs-server | grep inactive'
	chkrc 1 "nfs-server should has been started"
