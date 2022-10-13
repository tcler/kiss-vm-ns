#!/bin/bash

gitrepo=git://git.linux-nfs.org/projects/mora/nfstest.git

[[ -f /usr/bin/git ]] || {
	yum install -y git
}

echo "{nfstest-install} from $gitrepo"
git clone $gitrepo || exit $?
export PYTHONPATH=$PWD/nfstest
export PATH=$PWD/nfstest/test:$PATH

cat <<-EOF >nfstest.env
export PYTHONPATH=$PWD/nfstest
export PATH=$PWD/nfstest/test:$PATH
EOF
