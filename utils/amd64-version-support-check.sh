#!/bin/bash
#Author: Jianhong Yin <yin-jianhong@163.com>
#inspired by https://unix.stackexchange.com/questions/631217/how-do-i-check-if-my-cpu-supports-x86-64-v2/631226#631226
#`-> but gives the missing flags
#
#note: the words in the flags list might be just a pattern.
#`-> e.g lahf is just a prefix of flags like: lahf_*

v1="lm cmov cx8 fpu fxsr mmx syscall sse2"; 
v2="cx16 lahf popcnt sse4_1 sse4_2 ssse3";
v3="avx avx2 bmi1 bmi2 f16c fma abm movbe xsave";
v4="avx512f avx512bw avx512cd avx512dq avx512vl"; 

vflags=("$v1" "$v2" "$v3" "$v4")
cpuflags=$(awk -F'[: ]+' '/^flags/{$1=""; print}' /proc/cpuinfo)

for ((i=0; i<${#vflags[@]}; i++)); do
	echo "{debug} v$i: ${vflags[$i]}"
	rt=1;
	missing=();
	for flag in ${vflags[$i]}; do
		grep -q $flag <<<"$cpuflags" || missing+=($flag);
	done;
	if [[ ${#missing[@]} -gt 0 ]]; then
		rt=0;
		echo "support amd64-v$((i+rt))   #missing v$((i+rt+1)) flags: (${missing[*]})/${vflags[$i]}";
		break;
	fi
done
