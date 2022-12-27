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
	local _rc=$?
	local xrange=${1:-0}; shift
	local comment=
	local RC=$(printenv _RC)
	RC=${RC:-${_rc}}
	if [[ $# -eq 0 ]]; then
		comment="return code($RC), expected range($xrange)"
	else
		comment="$*"
	fi
	if rc_isexpected "$xrange" $RC; then
		echo -e "\E[1;34m{TEST PASS} $comment\E[0m"
	else
		echo -e "\E[1;31m{TEST FAIL} $comment\E[0m"
	fi
	return $RC
}

quote() {
	local at=$1
	if [[ -z "$at" ]]; then
		echo -n "'' "
	elif [[ "$at" =~ [^[:print:]]+ || "$at" = *$'\t'* || "$at" = *$'\n'* ]]; then
		builtin printf %q "$at"; echo -n " "
	elif [[ "$at" =~ "'" && ! "$at" =~ ([\`\"$]+|\\\\) ]]; then
		echo -n "\"$at\" "
	else
		echo -n "$at" | sed -r -e ':a;$!{N;ba};' \
			-e "s/'+/'\"&\"'/g" -e "s/^/'/" -e "s/$/' /" \
			-e "s/^''//" -e "s/'' $/ /"
	fi
}

_CODE_IN_ARGV=no
getReusableCommandLine() {
	#if only one parameter, treat it as a piece of script
	[[ $# = 1 ]] && { echo "$1"; return; }

	local shpattern='^[][0-9a-zA-Z~@%^_+=:,./-]+$'

	for at; do
		if [[ "$_CODE_IN_ARGV" = yes ]]; then
			if [[ -z "$at" || "$at" =~ ^q#.+$ ]]; then
				quote "${at:2}"
			else
				echo -n "$at "
			fi

			continue
		fi

		if [[ "$at" =~ $shpattern ]]; then
			echo -n "$at "
		else
			quote "$at"
		fi
	done
	echo
}

TEST_LOGPATH=${TEST_LOGPATH:-.}
_RC=
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
		Usage: trun [options] command [cmd-opts] [args]
		Examples:
		  trun  'echo "$exportdir *(rw,no_root_squash)" >/etc/exports'
		  trun  'ls *.sh -l'
		  trun  'var=$(ls)'
		  trun  'find . -type f | grep ^$path$'
		  trun  sudo systemctl restart nfs-server
		  trun  echo 'say "hello world"' "I'm a student"
		  trun  'systemctl status nfs-server | grep inactive'
		  trun  -eval systemctl status nfs-server \| grep inactive
		  trun  -as=user -x0 touch /root/file
		  trun  -x0 grep pattern /path/to/file

		  trun -nohup tail -f /path/to/file
		  trun -nohup=nohup-log-file tail -f /path/to/file
		  trun -tmux=sessoin-name tail -f /path/to/file
		EOF
		return 0
	}

	[[ $# -eq 0 ]] && return 0
	[[ $# -eq 1 && -z "$_runtype" ]] && _runtype=eval
	[[ "${_runtype}" = eval && -n "$_SUDO" ]] && _SUDO+=\ -s
	local _cmdl=$(getReusableCommandLine "$@")
	local _cmdlx=
	[[ $# -ne 1 && "$_runtype" =~ (eval|bash) ]] &&
		_cmdl=$(_CODE_IN_ARGV=yes getReusableCommandLine "$@")

	if [[ "$_debug" = yes ]]; then
		_cmdlx="$_cmdl"
		if [[ "${_runtype}" = tmux ]]; then
			_cmdlx="tmux new -s $_tmuxSession -d \"$_cmdl\" \\; pipe-pane \"cat >$_tmuxlogf\""
		elif [[ "$_nohup" = yes ]]; then
			_cmdlx="nohup $_cmdl &>${_nohuplogf} &"
		fi
		[[ -n "$_SUDO" ]] && _cmdlx="$_SUDO  $_cmdlx"
		echo "[$(date +%T) $USER $PWD]"$'\n\E[0;33;44m'"run(${_runtype:-plat})> $_cmdlx"$'\E[0m'
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
	[[ "$_chkrc" = yes ]] && { _RC=$_RC chkrc $_xrcrange; }
	return $_rc
}
trun() { run -d "$@"; }
xrc() { chkrc "$@"; }

curl_download() {
	local filename=$1
	local url=$2
	shift 2;

	local curlopts="-f -L -k"
	local header=
	local fsizer=1
	local fsizel=0
	local rc=

	[[ -z "$filename" || -z "$url" ]] && {
		echo "Usage: curl_download <filename> <url> [curl options]" >&2
		return 1
	}

	header=$(curl -L -I -s $url|sed 's/\r//')
	fsizer=$(echo "$header"|awk '/Content-Length:/ {print $2; exit}')
	if echo "$header"|grep -q 'Accept-Ranges: bytes'; then
		curlopts+=' --continue-at -'
	fi

	echo "{VM:INFO} run: curl -o $filename \$url $curlopts $curlOpt $@"
	run -as=$VMUSER curl -o $filename $url $curlopts $curlOpt "$@"
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
curl_download_x() { until curl_download "$@"; do sleep 1; done; }

#return if I'm being sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[ $sourced = yes ]]; then return 0; fi

#__main__
echo "[INFO] this is a lib file, run internal test:"
trun -x ls --color=always /root
run switchroot "$@"
trun 'for ((i=0; i<8; i++)); do echo $i; done'
trun 'var=$(ls -l)'
trun -x 'grep OS /etc/os-release'
trun 'grep OS /etc/os-release'
	xrc 1 "there should not be OS string in /etc/os-release"
trun 'grep RHEL /etc/os-release'
	xrc 0 "there should be RHEL string in /etc/os-release"
trun 'systemctl status nfs-server | grep inactive'
	xrc 1 "nfs-server should has been started"

trun -eval systemctl status nfs-server \| grep inactive
