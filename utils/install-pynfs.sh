
OSVER=$(rpm -E %rhel)

#enable epel
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSVER}.noarch.rpm

#install python3 and pip3
if [[ $OSVER < 9 ]]; then
	case $OSVER in
	8) sudo yum install -y python39 python39-pip python39-devel;;
	7) sudo yum install -y python36 python36-pip python36-devel;;
	6) sudo yum install -y python34 python34-pip python34-devel;;
	5) echo "[WARN] does not support rhel-5 and before.";;
	esac
else
	sudo yum install -y python3-pip python3-devel
fi

#install dependency
sudo yum install -y gcc krb5-devel swig

#install module ply
if pip3 install -h|grep .--break-system-packages; then
	pipOpt=--break-system-packages
fi
yes | sudo pip3 install $pipOpt ply
yes | sudo pip3 install $pipOpt gssapi

#git clone pynfs
_xdir=pynfs
targetdir=/usr/src; [[ $(id -u) != 0 ]] && { targetdir=${HOME}/src; }
mkdir -p ${targetdir}; rm -rf ${targetdir}/$_xdir
which git 2>/dev/null || sudo yum install -y git
pushd $targetdir
	PynfsUrl=git://git.linux-nfs.org/projects/bfields/pynfs.git
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
