#!/bin/bash

watch -n 1 'echo CPU: $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]°; grep cpu.MHz /proc/cpuinfo | sort'
