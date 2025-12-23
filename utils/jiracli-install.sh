#!/bin/bash

durl=$(curl -sL https://api.github.com/repos/ankitpokhrel/jira-cli/releases/latest |
	jq -r '.assets[] | select(.name? | match("linux.*x86_64")) | .browser_download_url')
fname=${durl##*/}

tmpdir=$(mktemp -d)
pushd $tmpdir
curl -LO $durl
tar axf $fname
find ${fname%.tar.gz}
if [[ $(id -u) = 0 ]]; then
	cp -v ${fname%.tar.gz}/bin/jira /usr/local/bin/
else
	mkdir -p ~/.local/bin
	cp -v ${fname%.tar.gz}/bin/jira ~/.local/bin/
fi
popd
rm -rf $tmpdir

echo
command -v jira
