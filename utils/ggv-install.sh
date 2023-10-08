#!/bin/bash
# this script is used to install gm(GraphicsMagick/ImageMagick) gocr and vncdotool

[[ $(id -u) != 0 ]] && {
	echo -e "{WARN} $0 need root permission, please try:\n  sudo $0 ${@}" | GREP_COLORS='ms=1;31' grep --color=always . >&2
	exit 126
}

. /etc/os-release
OS=$NAME

case ${OS,,} in
slackware*)
	sbopkg-install.sh
	sbopkg_install() {
		local pkg=$1
		sudo /usr/sbin/sqg -p $pkg
		yes $'Q\nY\nP\nC' | sudo /usr/sbin/sbopkg -B -i $pkg
	}
	;;
red?hat|centos*|rocky*|anolis*)
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] &&
			yum $yumOpt install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	;;
esac

#install netpbm/netpbm-progs or gm(GraphicsMagick/ImageMagick)
#! command -v gm && ! command -v convert && {
! command -v anytopnm && {
	echo -e "\n{ggv-install} install netpbm or GraphicsMagick/ImageMagick ..."
	case ${OS,,} in
	slackware*)
		/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install netpbm
		;;
	fedora*|red?hat*|centos*|rocky*|anolis*)
		yum $yumOpt install -y netpbm-progs
		;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y netpbm
		;;
	opensuse*|sles*)
		zypper in --no-recommends -y netpbm
		;;
	*)
		: #fixme add more platform
		;;
	esac

	#if install netpbm failed, use GraphicsMagick/ImageMagick instead
	if ! command -v anytopnm >/dev/null; then
		case ${OS,,} in
		slackware*)
			/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install imagemagick
			;;
		fedora*|red?hat*|centos*|rocky*|anolis*)
			yum $yumOpt install -y GraphicsMagick; command -v gm || yum $yumOpt install -y ImageMagick
			;;
		debian*|ubuntu*)
			apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y graphicsmagick; command -v gm || apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y imagemagick
			;;
		opensuse*|sles*)
			zypper in --no-recommends -y GraphicsMagick; command -v gm || zypper in --no-recommends -y ImageMagick
			;;
		*)
			: #fixme add more platform
			;;
		esac
	fi
}

#install gocr
echo
! command -v gocr && {
	echo -e "\n{ggv-install} install gocr ..."

	case ${OS,,} in
	slackware*)
		sbopkg_install gocr
		;;
	fedora*|red?hat*|centos*|rocky*|anolis*)
		yum $yumOpt install -y gocr || yum-install-from-fedora.sh gocr;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y gocr;;
	opensuse*|sles*)
		zypper in --no-recommends -y gocr;;
	*)
		:;; #fixme add more platform
	esac

	command -v gocr || {
		echo -e "\n{ggv-install} install gocr from src ..."
		case ${OS,,} in
		fedora*|red?hat*|centos*|rocky*|anolis*)
			yum $yumOpt install -y git autoconf gcc make netpbm-progs;;
		debian*|ubuntu*)
			apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y git autoconf gcc make netpbm;;
		opensuse*|sles*)
			zypper in --no-recommends -y git autoconf gcc make netpbm;;
		*)
			:;; #fixme add more platform
		esac

		while true; do
			rm -rf gocr
			_url=https://github.com/tcler/gocr
			while ! git clone --depth=1 $_url; do [[ -d gocr ]] && break || sleep 5; done
			(
			cd gocr
			./configure --prefix=/usr && make && make install
			)
			command -v gocr && break

			sleep 5
			echo -e " {ggv-install} installing gocr fail, try again ..."
		done
	}
}

install_python_pip() {
	if command -v pip3; then
		return 0
	fi

	case ${OS,,} in
	slackware*)
		/usr/sbin/slackpkg -batch=on -default_answer=y -orig_backups=off install python3;;
	fedora*|red?hat*|centos*|rocky*|anolis*)
		python_pkgs="python3-pip"
		[[ $(rpm -E %rhel) = 8 ]] && python_pkgs="python39-pip"
		yum $yumOpt --setopt=strict=0 install -y python-devel python-pip platform-python-devel $python_pkgs;;
	debian*|ubuntu*)
		apt install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -y python-pip python3-pip;;
	opensuse*|sles*)
		zypper in --no-recommends -y python-pip python3-pip;;
	*)
		:;; #fixme add more platform
	esac
}

#install vncdotool
fastesturl() {
	local minavg=
	local fast=
	local ipv4Opt=
	ping -h |& grep -q '^ *-4' && ipv4Opt=-4

	for url; do
		if curl -L -s --head --request GET ${url} | grep -q "404 Not Found"; then
			echo "[WARN] return 404 while access: ${url}" >&2
			continue
		fi
		read p host path <<<"${url//\// }";
		cavg=$(ping $ipv4Opt -w 4 -c 2 $host | awk -F / 'END {print $5}')
		: ${minavg:=$cavg}

		if [[ -z "$cavg" ]]; then
			echo -e " -> $host\t 100% packet loss." >&2
			continue
		else
			echo -e " -> $host\t $cavg  \t$minavg" >&2
		fi

		fast=${fast:-$url}
		if awk "BEGIN{exit !($cavg<$minavg)}"; then
			minavg=$cavg
			fast=$url
		fi
	done

	echo $fast
}

echo
pipOpts="--default-timeout=60 --retries=10"
pipDefaultUrl=https://files.pythonhosted.org
pipMirrorList="$pipDefaultUrl
https://pypi.tuna.tsinghua.edu.cn/simple
https://mirrors.aliyun.com/pypi/simple"
fastUrl=$(fastesturl $pipMirrorList)
[[ -n "$fastUrl" && "$fastUrl" != "$pipDefaultUrl" ]] && pipInstallOpts="-i $fastUrl"
echo -e "\n{ggv-install} install python pip ..."
install_python_pip
PIP=$(command -v pip3) || PIP=$(command -v pip)
if $PIP install -h|grep .--break-system-packages; then
	pipInstallOpts+=" --break-system-packages"
fi

if ! command -v vncdo; then
	echo -e "{ggv-install} pip Opts: $pipOpts $pipInstallOpts ..."
	echo -e "\n{ggv-install} install vncdotool ..."
	$PIP $pipOpts install $pipInstallOpts --upgrade pip
	$PIP $pipOpts install $pipInstallOpts --upgrade setuptools
	#dataclasses is needed on rhel-7
	python3 --version |& grep -q '3\.6' &&
		$PIP $pipOpts install $pipInstallOpts dataclasses
	$PIP $pipOpts install $pipInstallOpts vncdotool service_identity
else
	$PIP $pipOpts install $pipInstallOpts --upgrade vncdotool service_identity
fi
