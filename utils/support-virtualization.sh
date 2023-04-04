#!/bin/bash

support_virtualization() {
	local rc=1
	case ${OSTYPE,,} in
	linux-gnu*) grep -E -q -wo '(vmx|svm)' /proc/cpuinfo && rc=0;;
	freebsd)    dmesg | grep -q -e VT-x: -e SVM: && rc=0;;
	*)          echo "{WARN} unsupported OS/platform." >&2;;
	esac
	return $rc
}

support_virtualization
