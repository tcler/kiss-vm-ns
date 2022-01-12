#!/bin/bash

watch -t -n 1 '
	date
	echo
	if test -f /sys/class/thermal/thermal_zone0/temp; then
		echo CPU: $(($(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null||echo 0)/1000))°
	else
		sensors|sed -n "/Physical id 0/{s/[^+]*+//; p;}"
	fi
	echo
	grep cpu.MHz /proc/cpuinfo | sort'
