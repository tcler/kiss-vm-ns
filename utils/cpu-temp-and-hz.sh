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
	else
		sensors|sed -n "/Physical id 0/{s/[^+]*+//; p;}"
	fi
	echo
	grep cpu.MHz /proc/cpuinfo | sort'
