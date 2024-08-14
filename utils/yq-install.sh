#!/usr/bin/env bash

if yq -h |& grep -q mikefarah; then
	echo "[INFO] yq has been installed: $(which yq)"
	exit 0
fi

downhostname=download.devel.redhat.com
LOOKASIDE_BASE_URL=${LOOKASIDE:-http://${downhostname}/qa/rhts/lookaside}

is_rh_intranet() { host ipa.redhat.com &>/dev/null; }
is_rh_intranet2() { grep -q redhat.com /etc/resolv.conf || is_rh_intranet; }
is_rh_intranet2 && export https_proxy=squid.redhat.com:8080

arch=$(uname -m)
case $arch in
x86_64)  arch=amd64;;
aarch64) arch=arm64;;
esac

eval installpath=~/bin
[[ $(id -u) = 0 ]] && installpath=/usr/bin

if is_rh_intranet; then
	YQ_URL=${LOOKASIDE_BASE_URL}/yq/v4.35.2/yq_linux_$arch
else
	YQ_URL=https://github.com/mikefarah/yq/releases/download/v4.35.2/yq_linux_$arch
	YQ_URL=$(curl -Ls https://api.github.com/repos/mikefarah/yq/releases/latest |
		sed -rn "/^.*(https:.*yq_linux_$arch)\"$/{s//\1/;p}")
fi
echo "[yq-install.sh] downloading yq from: ${YQ_URL} .."
curl -L "$YQ_URL" -o $installpath/yq
chmod +x $installpath/yq
which yq
