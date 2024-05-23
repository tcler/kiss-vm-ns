#!/bin/bash

FRRVER=frr-stable
if command -v yum; then
	verx=$(rpm -E %rhel)
	if [[ "$verx" != %rhel ]]; then
		frrRepoRpmUrl=https://rpm.frrouting.org/repo/$FRRVER-repo-1-0.el${verx}.noarch.rpm
		sudo yum install -y $frrRepoRpmUrl  #${FRRVER}*
	fi
	sudo yum install --setopt=strict=0 -y frr frr-pythontools
fi
