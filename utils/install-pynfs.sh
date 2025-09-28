
OSVER=$(rpm -E %rhel)

#enable epel
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSVER}.noarch.rpm

#install python3 and pip3
if [[ $OSVER != %rhel && $OSVER -lt 9 ]]; then
	case $OSVER in
	8) sudo yum install -y python39 python39-pip python39-devel;;
	*) echo "[WARN] does not support rhel-7 and before."; exit 1;;
	esac
else
	sudo yum install -y python3-pip python3-devel
fi

#install dependency
sudo yum install -y gcc krb5-devel swig python3-devel python3-gssapi python3-ply

#install module xdrlib3
if pip3 install -h|grep .--break-system-packages; then
	pipOpt=--break-system-packages
fi
yes | sudo pip3 install $pipOpt xdrlib3

#git clone pynfs
_xdir=pynfs
PynfsUrl=git://git.linux-nfs.org/projects/bfields/pynfs.git
PynfsUrl=git://git.linux-nfs.org/projects/cdmackay/pynfs.git
[[ -n "$1" ]] && PynfsUrl="$1"
targetdir=/usr/src; [[ $(id -u) != 0 ]] && { targetdir=${HOME}/src; }
mkdir -p ${targetdir}; rm -rf ${targetdir}/$_xdir
which git 2>/dev/null || sudo yum install -y git
pushd $targetdir
	git clone $PynfsUrl $_xdir
	(cd $_xdir; python3 ./setup.py install)
popd

#export env
_envf=/tmp/pynfs.env
cat <<-EOF >$_envf
export PYTHONPATH=$targetdir/$_xdir/nfs4.1
export PATH=$targetdir/$_xdir/nfs4.1:$PATH
EOF
echo "{info} please source '$_envf', and run your tests"
cat $_envf >>~/.bashrc
