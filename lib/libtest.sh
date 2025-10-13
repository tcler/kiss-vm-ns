#!/bin/bash

#ref: https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
(return 0 2>/dev/null) && sourced=yes || sourced=no
if [[  $sourced = yes && "$KISS_LIB_LOADED" = yes ]]; then
	echo "{warn} kiss test lib has been loaded" >&2
	return 0
fi

KISS_LIB_LOADED=yes
KISS_FAIL_CNT=0
KISS_PASS_CNT=0
_RC=

switchroot() {
	local P=$0 SH=; [[ -x $0 && $PATH =~ (^|:)${0%/*}(:|$) ]] && command -v ${0##*/} &>/dev/null && P=${0##*/}; [[ ! -f $P || ! -x $P ]] && SH=$SHELL
	#[[ $# -eq 0 ]] && set -- "${BASH_ARGV[@]}" #need enable extdebug: shopt -s extdebug
	[[ $(id -u) != 0 ]] && {
		if [[ "${SHELL##*/}" = $P ]]; then
			echo -e "\E[1;31m{WARN} $P need root permission, please add sudo before $P\E[0m" >&2
			exit
		else
			echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m" >&2
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
	if [[ "$xrange" = - ]]; then
		return $RC
	elif rc_isexpected "$RC" "$xrange"; then
		let KISS_PASS_CNT++
		echo -e "\E[1;34m{KISS.TEST PASS} ($RC/$xrange)  #$comment\E[0m"
	else
		let KISS_FAIL_CNT++
		echo -e "\E[1;31m{KISS.TEST FAIL} ($RC/$xrange)  #$comment\E[0m"
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

run() {
	#ref: https://superuser.com/questions/927544/run-command-in-detached-tmux-session-and-log-console-output-to-file
	local _logpath=${TEST_LOGPATH}
	local _runtype= _debug= _rc=0
	local _nohup= _nohuplogf=
	local _user= _SUDO=
	local _default_nohuplogf=
	local _tmuxSession= _tmuxlogf= _tmuxSOpt= _ppaneOpt=
	local _xrcrange= _chkrc=no
	local _logf=

	while true; do
		case "$1" in
		-d|-debug) _debug=yes; shift;;
		-eval*) _runtype=eval; shift;;
		-bash*) _runtype=bash; shift;;
		-logpath*) _runtype=tmux;
			[[ $1 = *=* ]] && _logpath=${1#*=}
			shift;;
		-logf*) _runtype=tmux;
			[[ $1 = *=* ]] && _logf=${1#*=}
			shift;;
		-tmux*) _runtype=tmux;
			[[ $1 = *=* ]] && _tmuxSession=${1#*=}
			shift;;
		-nohu*) _nohup=yes
			[[ $1 = *=* ]] && _nohuplogf=${1#*=}
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
		  trun -tmux[=sessoin-name] vm create $distro  #will auto generate session-name if ommited, log file name: run-tmux-${session}.log
		  trun -tmux -logpath=$HOME/log vm create CentOS-9 -I=$HOME/Downloads/cs9.qcow2  #default logpath is /tmp
		  trun -tmux -logfile=$pathto/logfile vm create CentOS-9 -I=$HOME/Downloads/cs9.qcow2  #overwrite -logpath and default log file name
		  trun -tmux=- vm create CentOS-9 -I=$HOME/Downloads/cs9.qcow2  #no session name, and do not create session log file
		EOF
		return 0
	}

	[[ "$_nohup" = yes ]] && {
		_default_nohuplogf=${_logpath:-.}/nohup.log
		_nohuplogf=${_nohuplogf:-$_default_nohuplogf}
	}
	[[ "$_runtype" = tmux ]] && {
		_tmuxSession=${_tmuxSession:-kissrun-$$-${USER}-s$((_TMUX_SID++))}
		_tmuxSOpt="-s $_tmuxSession"
		_tmuxlogf=${_logf:-${_logpath:-/tmp}/run-tmux-${_tmuxSession}.log}
		_ppaneOpt="-t ${_tmuxSession//[:.]/_}:0.0"
		if [[ "$_tmuxSession" = - ]]; then
			_tmuxSOpt=
			_tmuxlogf=/dev/null
			_ppaneOpt=
		fi
	}

	[[ $# -eq 0 ]] && return 0
	[[ $# -eq 1 && -z "$_runtype" ]] && _runtype=eval
	[[ "${_runtype}" = eval && -n "$_SUDO" ]] && _SUDO+=\ -s
	local _cmdl= _cmdlx=
	local _cmdl=$(getReusableCommandLine "$@")
	[[ $# -ne 1 && "$_runtype" =~ (eval|bash) ]] &&
		_cmdl=$(_CODE_IN_ARGV=yes getReusableCommandLine "$@")

	if [[ "$_debug" = yes ]]; then
		_cmdlx="$_cmdl"
		if [[ "${_runtype}" = tmux ]]; then
			_cmdlx="tmux new $_tmuxSOpt -d \"$_cmdl\" \\; pipe-pane $_ppaneOpt \"exec cat >$_tmuxlogf\""
		elif [[ "$_nohup" = yes ]]; then
			_cmdlx="nohup $_cmdl &>${_nohuplogf} &"
		fi
		[[ -n "$_SUDO" ]] && _cmdlx="$_SUDO  $_cmdlx"
		echo "[$(date +%T) $USER $PWD]"$'\n\E[0;33;44m'"run(${_runtype:-plat})> ${_cmdlx}"$'\E[0m'
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
	tmux)   $_SUDO tmux new $_tmuxSOpt -d "$_cmdl" \; pipe-pane $_ppaneOpt "exec cat >$_tmuxlogf"; _rc=$?;;
	esac

	_RC=$_rc
	[[ "$_chkrc" = yes ]] && { _RC=$_RC chkrc $_xrcrange; }
	return $_rc
}
trun() { run -d "$@"; }
xrc() { chkrc "$@"; }
tcnt() { echo -e "\n{KISS.TEST COUNT} $KISS_FAIL_CNT test fail, $KISS_PASS_CNT test pass."; }

is_available_url() { curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail "$1" &>/dev/null; }
is_rh_intranet() { host ipa.corp.redhat.com &>/dev/null; }
is_rh_intranet2() { grep -q redhat.com /etc/resolv.conf || is_rh_intranet; }

_gen_distro_dir_name() {
	local distro=$1 arch=$2 suffix=$3
	local distrodir=${distro}.${arch}; [[ -n "${suffix}" ]] && distrodir+=+${suffix}
	echo $distrodir
}
gen_distro_dir_name() {
	#generate the distro-dir-name that will be used to making test-result-dir
	local vmname=$1
	local suffix=$2
	local arch=$(vm exec $vmname -- uname -m)
	if [[ -z "$arch" ]]; then
		arch=$(vm xml $vmname | sed -rn -e "/^.*arch='([^']+)' .*$/{s//\1/;p}" -e '/.*\.([^.]+)\.qcow2.*/{s//\1/;p}' | tail -1)
	elif [[ "$arch" = *pass* ]]; then
		arch=
	fi
	local distro=$(vm homedir $vmname|awk -F/ 'NR==1{print $(NF-1)}')
	[[ -z "${arch}" || -z "${distro}" ]] && return 1
	_gen_distro_dir_name $distro $arch $suffix
}

vmrunx() {
	local comment=
	local _xrange_and_comment=${1} vmname=${2}; shift 2
	read _xrange comment <<<"${_xrange_and_comment/:/ }"
	[[ "${_xrange}" =~ ^[0-9,-]+$ ]] || {
		cat <<-ERR_MSG >&2
		{error} invalid expected return codes format: ${_xrange}
		Usage: ${FUNCNAME} <0|1-255|1-8,124,127|-[:comment]> <vmname> <command [options or arguments]>
		ERR_MSG
		return 2
	}
	[[ "${1}" = -- ]] && shift 1
	vm exec -v ${vmname} -- "${@}"
	chkrc "${_xrange}" "${comment}"
}

#return if I'm being sourced
if [[ $sourced = yes ]]; then return 0; fi

#__main__
echo "[INFO] this is a lib file, run internal test:"
trun -x ls --color=always /root
run switchroot "$@"
trun 'for ((i=0; i<8; i++)); do echo $i; done'
trun 'var=$(ls -l)'
trun -x 'grep -w OS /etc/os-release'
trun 'grep -w OS /etc/os-release'
	xrc 1,2,3,4-255 "there should not be word OS in /etc/os-release"
trun 'grep RHEL /etc/os-release'
	xrc 0 "there should be RHEL string in /etc/os-release"
trun 'systemctl status nfs-server | grep inactive'
	xrc 1 "nfs-server should has been started"

trun -eval systemctl status nfs-server \| grep inactive

tcnt
