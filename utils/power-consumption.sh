#!/bin/bash
#autor: Jianhong Yin <yin-jianhong@163.com>
#function: get cpu power consumption of current computer. #just for fun
#ref: https://www.kernel.org/doc/html/next/power/powercap/powercap.html
#ref: https://www.baeldung.com/linux/power-consumption
#ref: https://www.onitroad.com/jc/faq/how-to-measure-power-consumption-using-powerstat-in-linux.html

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() {  needroot; }
switchroot "$@"

stime() {
	local timestr=${1,,} secs= timen= unit=
	read timen unit <<<$(echo $timestr|sed 's/[smh]$/ &/')
	case $unit in (*h) secs=$((timen*60*60));; (*m) secs=$((timen*60));; (*) secs=$timen;; esac
	echo $secs
}
powercap() {
	local time=${1,,}
	local ZN=($(sudo cat /sys/class/powercap/*/name))      #Name of the power zone
	[[ -z "${ZN}" ]] && { echo -e "{ERR} feature 'powercap' is required, seems current platform does not support it." >&2; return 1; }
	local E0=($(sudo cat /sys/class/powercap/*/energy_uj)) #energy counter in micro joules at _time A
	local stime=$(stime $time)
	{
	echo "Running for $time($stime seconds). then calculate the average power during this period"
	for ((i=1; i <= stime; i++)); do case $((i%4)) in 0)p=/;; 1)p=-;; 2)p=\\;; 3)p=\|;; esac; echo -ne "\r$p $i"; sleep 1; done; echo
	} >&2
	E1=($(sudo cat /sys/class/powercap/*/energy_uj)) #energy counter in micro joules at _time A + $time

	for i in "${!E0[@]}"; do
		awk -v ZN=${ZN[i]} -v E1=${E1[i]} -v E0=${E0[i]} -v stime=$stime 'BEGIN { printf "%s: %.1f W\n", ZN, (E1-E0) / stime / 1e6 }'
	done | awk '{ print; sum+=$2 } END { printf "[total]: %.1f W\n", sum }'
}

time=${1:-8}; [[ $time = [.k-] ]] && time=8
[[ ${time,,} =~ ^[0-9]+[smh]?$ ]] || { echo -e "{ERR} '$time' is not a valid time string.\nUsage: $0 [\$during_time[smh] [ps]]" >&2; exit 1; }
powercap ${time,,}

if [[ -n "$2" ]] && command -v powerstat &>/dev/null; then
	powerstat_cmd="powerstat -R -c -z 5 12"
	echo "{DEBUG} running: $powerstat_cmd"
	$powerstat_cmd
fi
