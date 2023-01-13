#!/usr/bin/env bash

if yq -h | grep -q mikefarah; then
	echo "[INFO] yq has been installed: $(which yq)"
	exit 0
fi

arch=$(uname -m)
case $arch in
x86_64)  arch=amd64;;
aarch64) arch=arm64;;
esac

eval installpath=~/bin
[[ $(id -u) = 0 ]] && installpath=/usr/bin

YQ_URL=https://github.com/mikefarah/yq/releases/download/v4.30.5/yq_linux_$arch
wget -q "$YQ_URL" -O $installpath/yq
chmod +x $installpath/yq
which yq
