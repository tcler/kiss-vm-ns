
OSVER=$(rpm -E %rhel)

#enable epel
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSVER}.noarch.rpm

#install python3 and pip3
if [[ $OSVER < 8 ]]; then
	case $OSVER in
	7)
		sudo yum install -y python36 python36-pip
		;;
	6)
		sudo yum install -y python34 python34-pip
		;;
	5)
		echo "[WARN] does not support rhel-5 and before."
		;;
	esac
else
	sudo yum install -y python3-pip
fi

#install dependency
yum install -y gcc krb5-devel python-devel swig
yum install -y platform-python-devel

#install module ply
yes | sudo pip3 install ply
yes | sudo pip3 install gssapi

#git clone pynfs
sudo yum install -y git
PynfsUrl=git://git.linux-nfs.org/projects/bfields/pynfs.git
git clone $PynfsUrl
(cd pynfs; python3 ./setup.py install)
