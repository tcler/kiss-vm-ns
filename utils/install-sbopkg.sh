#!/bin/bash

. /etc/os-release
osname=$NAME
osver=$VERSION

if [[ "${osname,,}" != slackware* ]]; then
	echo "{WARN} your os is not slackware" >&2
else
	export PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH
	if ! command -v sbopkg; then
		#install sbopkg
		urlpath=$(curl -s -L https://github.com/sbopkg/sbopkg/releases | grep -o /sbopkg/.*/sbopkg-.*.tgz | head -n1)
		wget https://github.com/$urlpath
		sudo installpkg ${urlpath##*/}
		rm -f ${urlpath##*/}

		#configure sbopkg
		echo C | sudo /usr/sbin/sbopkg -V ?
		repo=$(sudo /usr/sbin/sbopkg -V ? |& awk -v repo=SBo/$osver '$1 == repo {print $1}')
		repo=${repo:-SBo-git/current}
		read rname rbranch <<<"${repo/\// }"
		sudo sed -ri -e 's#(^REPO_BRANCH)=.*#\1=${\1:-'"$rbranch"'}#' \
			-e 's#(^REPO_NAME)=.*#\1=${\1:-'"$rname"'}#' /etc/sbopkg/sbopkg.conf
		sudo sed -ri '/^REPO_(NAME|BRANCH)=/d' /usr/sbin/sqg
		echo C | sudo /usr/sbin/sbopkg -r
	fi
fi
