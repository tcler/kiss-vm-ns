#!/usr/bin/env bash

if yq -h |& grep -q mikefarah; then
	echo "[INFO] yq has been installed: $(which yq)"
	exit 0
fi

is_rh_intranet() { host ipa.redhat.com &>/dev/null; }
is_rh_intranet() { grep -q redhat.com /etc/resolv.conf; }
is_rh_intranet && export https_proxy=squid.redhat.com:8080

arch=$(uname -m)
case $arch in
x86_64)  arch=amd64;;
aarch64) arch=arm64;;
esac

eval installpath=~/bin
[[ $(id -u) = 0 ]] && installpath=/usr/bin

if is_rh_intranet; then
	YQ_URL=http://download.devel.redhat.com/qa/rhts/lookaside/yq/v4.35.2/yq_linux_$arch
else
	YQ_URL=https://github.com/mikefarah/yq/releases/download/v4.35.2/yq_linux_$arch
	YQ_URL=$(curl -Ls https://api.github.com/repos/mikefarah/yq/releases/latest |
		sed -rn "/^.*(https:.*yq_linux_$arch)\"$/{s//\1/;p}")
fi
echo "[yq-install.sh] downloading yq from: ${YQ_URL} .."
curl -L "$YQ_URL" -o $installpath/yq
chmod +x $installpath/yq
which yq
