#!/bin/bash

watch -n 1 '
	if command -v sensors &>/dev/null; then
		sensors|sed -n "/Physical id 0/{s/[^+]*+//; p;}"
	else
		echo CPU: $(($(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null||echo 0)/1000))°
	fi
	grep cpu.MHz /proc/cpuinfo | sort'
