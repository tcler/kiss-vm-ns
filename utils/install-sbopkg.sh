#!/bin/bash

. /etc/os-relese
osname=$NAME
osver=$VERSION

if [[ "$osname" != slackware* ]]; then
	echo "{WARN} your os is not slackware" >&2
else
	export PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH
	if ! command -v sbopkg; then
		#install sbopkg
		urlpath=$(curl -s -L https://github.com/sbopkg/sbopkg/releases | grep -o /sbopkg/.*/sbopkg-.*.tgz | head -n1)
		wget https://github.com/$urlpath
		installpkg ${urlpath##*/}
		rm -f ${urlpath##*/}

		#configure sbopkg
		repo=(sudo sbopkg -V ? | awk -v repo=SBo/$osver '$1 = repo /{print $1}/')
		repo=${repo:-SBo-git/current}
		sudo sed -r -i 's/(^REPO_BRANCH=).*/\1${REPO_BRANCH:-'"$repo"'}/' /etc/sbopkg/sbopkg.conf
		echo C | sudo sbopkg -V $repo
		sudo sbopkg -r
	fi
fi
