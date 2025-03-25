#!/bin/bash

watch -t -n 1 '
	date
	echo
	if test -f /sys/class/thermal/thermal_zone0/temp; then
		tempUnit=$"\\U2103"; [[ "$LANG" = C ]] && tempUnit=^C
		echo -n "CPU temp: {"
		for tempf in /sys/class/thermal/thermal_zone*; do
			echo -en "${tempf##*/thermal_}: $(($(cat $tempf/temp 2>/dev/null||echo 0)/1000))$tempUnit,"
		done
		echo "}"
	elif command -v sensors &>/dev/null; then
		sensors coretemp-isa-0000 2>/dev/null ||
			sensors -A | awk -v RS= '\''/k10temp/ {if (match($0, /\+[^ ]+/,m)) {print "cpu:", m[0]}}'\''
			sensors -A | awk -v RS= '\''/amdgpu/{if (match($0, /\+[^ ]+/,m)) {print "amdgpu:", m[0]}}'\''
	else
		echo "{warn} There is neither '/sys/class/thermal/*/temp' file nor command 'sensors'" >&2
	fi
	echo
	grep cpu.MHz /proc/cpuinfo | sort'
