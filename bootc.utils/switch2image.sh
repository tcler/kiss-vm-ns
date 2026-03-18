#!/bin/bash

BOOTC_TO=${BOOTC_TO}
REPOS=${REPOS}
PKGS=${PKGS}   # default package must exist on container so yum won't raise error.
BPKGS=${BPKGS} # use for brewinstall.sh
KOPTS=${KOPTS} # Only receive parameter with space "pci=realloc intel_iommu=on iommu=pt"
ScriptUrl=${ScriptUrl} # use for self define script
CMDL=${CMDL}
PART_MPS=${PART_MPS}

[[ -z "${BOOTC_TO}" ]] && { source /etc/os-release; BOOTC_TO=latest-${VERSION_ID}; }
MYIMAGE=mybootc:${BOOTC_TO}

arch_translate() {
	local arch=$1 narch=x86_64
	case $arch in (amd64) narch=x86_64;; (arm64) narch=aarch64;; esac
	echo $narch
}

genContainerfile() {
	cat <<-'CONTAINERFILE'
ARG BOOTC_TO
FROM images.paas.redhat.com/bootc/rhel-bootc:$BOOTC_TO
ARG BOOTC_TO
ARG PKGS
ARG BPKGS
ARG ScriptUrl
ARG CMDL
ARG PWD_HASH
ARG REPOS
ARG KOPTS

RUN echo "root:$PWD_HASH" | chpasswd -e

ADD ./fstab /etc/fstab.from.pkgmode
RUN cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/certs/{2022-IT-Root-CA.pem,Current-IT-Root-CAs.pem,ca.pem,mtls-ca-validators.crt} && update-ca-trust
RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
ADD ./resolv.conf /etc/resolv.conf
ADD ./repo/*.repo /etc/yum.repos.d/

# Install restraint,restraint-rhts and plugins
RUN <<EORUN
dnf -y --setopt=strict=0 --setopt=sslverify=0 --skip-broken --allowerasing install restraint \
restraint-rhts \
beakerlib \
beakerlib-redhat \
grub2-efi \
tuned \
tuned-profiles-nfv \
tuned-profiles-cpu-partitioning \
irqbalance \
python-unversioned-command \
policycoreutils-python-utils \
rpmdevtools \
man-db \
audit \
nfs-utils \
sudo
systemctl disable tuned
downhostname=download.eng.pek2.redhat.com
#rdu lab didn't has qe/rhts path
LOOKASIDE=http://$downhostname/qa/rhts/lookaside
LOOKASIDE_BASE_URL=$LOOKASIDE
bkrClientImprovedUrl=${LOOKASIDE_BASE_URL}/bkr-client-improved
_rpath=share/restraint/plugins/task_run.d
(cd /usr/$_rpath && curl -k -Ls --retry 64 --retry-delay 2 --remote-name-all $bkrClientImprovedUrl/$_rpath/{25_environment,27_task_require})
(cd /usr/${_rpath%/*}/completed.d && curl -k -Ls --retry 64 --retry-delay 2 -O $bkrClientImprovedUrl/${_rpath%/*}/completed.d/85_sync_multihost_tasks)
(cd /usr/bin && curl -k -Ls --retry 64 --retry-delay 2 -O $bkrClientImprovedUrl/utils/taskfetch.sh)
chmod a+x  /usr/$_rpath/* /usr/${_rpath%/*}/completed.d/* /usr/bin/taskfetch.sh
taskfetch.sh --install-deps
useradd -m -s /bin/bash test
passwd -l test
EORUN

COPY ./brewinstall.sh kiss-update.sh /usr/bin

RUN <<KARG
mkdir -p /usr/lib/bootc/kargs.d
cat <<EOF >> /usr/lib/bootc/kargs.d/console.toml
kargs = ["console=ttyS0,114800n8"]
EOF

if test -e /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service; then
	if grep Environment=NM_ONLINE_TIMEOUT /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service; then
		sed -i 's/Environment=NM_ONLINE_TIMEOUT.*/Environment=NM_ONLINE_TIMEOUT=600/' /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
	fi
fi
test -e /etc/systemd/system/kdump.service.d ||  mkdir -p /etc/systemd/system/kdump.service.d
if test -e /etc/systemd/system/kdump.service.d/wait-crash-mount.conf; then
	rm -rf /etc/systemd/system/kdump.service.d/wait-crash-mount.conf
fi

if test -n "${KOPTS}"; then
	cat <<-EOF >> /usr/lib/bootc/kargs.d/switch_pkg_self_define.toml
		kargs = [${KOPTS}]
	EOF
	cat /usr/lib/bootc/kargs.d/switch_pkg_self_define.toml
fi
KARG

RUN <<EORUN
#process env REPOS,PKGS,BPKGS,ScriptUrl,CMDL
set -xeuo pipefail
MAJOR=$(echo "$BOOTC_TO" | cut -d '-' -f 2 | cut -d '.' -f 1)
if curl -k -Ls --retry 64 --retry-delay 2 --remote-name-all https://dl.fedoraproject.org/pub/epel/epel-release-latest-"$MAJOR".noarch.rpm; then
	yum localinstall -y epel-release-latest-"$MAJOR".noarch.rpm && rm -rf epel-release-latest-"$MAJOR".noarch.rpm
	for repo in /etc/yum.repos.d/epel*.repo; do
		sed -i -e "s|\$releasever_major|${MAJOR}|g" \
			-e "s|\${releasever_minor:.*}||g" \
			-e '/^\s*skip_if_unavailable\s*=/d' \
			-e '/^\s*enabled\s*=\s*1\s*$/a skip_if_unavailable=1' \
			"$repo"
	done
fi

i=1
for url in ${REPOS//,/ }; do
	cat <<-EOF >/etc/yum.repos.d/my-repo$i.repo
	[my-repo$i]
	name=my-repo$i
	baseurl=$url
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	EOF
	let i++
done

#install package from PKGS
test -n "${PKGS}" && PKGS=$(rpm -q ${PKGS//,/ } | awk '/not.installed/{print $2}') || :
if [[ -n "${PKGS}" ]]; then
	dnf install -y --setopt=strict=0 --setopt=sslverify=0 --skip-broken --allowerasing ${PKGS} ||
		true #avoid break Containerfile build, if dnf does not return true
fi

#install package from BPKGS(brewinstall)
brewinstall.sh ${BPKGS//#/ } -noreboot -bootc || :

#running script from ScriptUrl
if test -n "${ScriptUrl}"; then
	url=${ScriptUrl%% *}; [ "x${url}" = "x${ScriptUrl}" ] || params=${ScriptUrl#* }
	curl -ksfL ${url} | bash -s -- ${params:-} || :
fi

#running command from CMDL
if test -n "${CMDL}"; then
	bash -c "${CMDL}" || :
fi
EORUN

RUN touch /var/tmp/switch-from-pkg-to-image
# must add containers.bootc and ostree.bootable, otherwise can't run bootc install
LABEL containers.bootc="1" \
		ostree.bootable="1" \
		org.opencontainers.image.version="${BOOTC_TO}" \
		bootc.diskimage-builder="quay.io/centos-bootc/bootc-image-builder" \
		redhat.id="RHEL" \
		redhat.version-id="${BOOTC_TO}" \
		redhat.pkgs="${PKGS}" \
		redhat.bpkgs="${BPKGS}" \
		redhat.scripturl="${ScriptUrl}" \
		redhat.cmdline="${CMDL}"
# https://pagure.io/fedora-kiwi-descriptions/pull-request/52 effect for quay.io/fedora/fedora:rawhide
# ENV container=oci
ENV container=oci

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
	CONTAINERFILE
}

bootc_install() {
	local authorized_keys_options=''
	if [[ -f /root/.ssh/authorized_keys ]]; then
		authorized_keys_options='--root-ssh-authorized-keys /target/root/.ssh/authorized_keys'
	fi

	# Installing to filesystem: Creating ostree deployment: Cannot re-deploy over extant stateroot
	# ostree fsck
	[[ -d /ostree ]] && rm -rf /ostree

	podman run --rm --tls-verify=false --privileged \
		--security-opt label=type:unconfined_t \
		--pid=host \
		-v /:/target \
		-v /dev:/dev \
		-v /var/lib/containers:/var/lib/containers \
		localhost/$MYIMAGE \
		bash -c "bootc install to-existing-root --target-transport containers-storage ${authorized_keys_options}"
	sync
	sleep 5
}

gen_repos() {
	local DISTRO=$1
	local arch=$2
	local repodir=${3:-repo}

	source /etc/os-release
	local verxy=${VERSION_ID}
	local verx=${verxy%%.*}
	local downhostname=download.devel.redhat.com
	local LOOKASIDE_BASE_URL=http://${downhostname}/qa/rhts/lookaside

	is_available_url() { local _url=$1; curl -L --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail $_url &>/dev/null; }

	DISTRO=$(echo "$DISTRO" | sed -r 's/-(arm64|amd64|ppc64|ppc64le|s390x?)$//')
	COMPOSE="http://$downhostname/rhel-$verx/composes/RHEL-$verx/$DISTRO/compose"
	is_available_url $COMPOSE ||
		COMPOSE="http://$downhostname/rhel-$verx/nightly/RHEL-$verx/latest-RHEL-$verxy/compose"

	rtype=rel-eng; [[ "$COMPOSE" = */nightly/* ]] && rtype=nightly
	bsurl=$COMPOSE/BaseOS/$arch/os
	debug_url=${bsurl/\/os/\/debug\/tree}
	Repos+=(
		BaseOS:${bsurl}
		AppStream:${bsurl/BaseOS/AppStream}
		CRB:${bsurl/BaseOS/CRB}
		HighAvailability:${bsurl/BaseOS/HighAvailability}
		NFV:${bsurl/BaseOS/NFV}
		ResilientStorage:${bsurl/BaseOS/ResilientStorage}
		RT:${bsurl/BaseOS/RT}
		SAP:${bsurl/BaseOS/SAP}
		SAPHANA:${bsurl/BaseOS/SAPHANA}

		BaseOS-debuginfo:${debug_url}
		AppStream-debuginfo:${debug_url/BaseOS/AppStream}
		CRB-debuginfo:${debug_url/BaseOS/CRB}
		HighAvailability-debuginfo:${debug_url/BaseOS/HighAvailability}
		NFV-debuginfo:${debug_url/BaseOS/NFV}
		ResilientStorage-debuginfo:${debug_url/BaseOS/ResilientStorage}
		RT-debuginfo:${debug_url/BaseOS/RT}
		SAP-debuginfo:${debug_url/BaseOS/SAP}
		SAPHANA-debuginfo:${debug_url/BaseOS/SAPHANA}
		Buildroot:http://$downhostname/rhel-$verx/$rtype/BUILDROOT-$verx/latest-BUILDROOT-$verx-RHEL-$verx/compose/Buildroot/$arch/os/
		beaker-harness:http://$downhostname/beakerrepos/harness/RedHatEnterpriseLinux${verx}
		nbeaker-harness:${LOOKASIDE_BASE_URL}/beaker-harness-active/rhel-${verx}
	)

	mkdir -p $repodir
	for repo in "${Repos[@]}"; do
		read _name _url <<<"${repo/:/ }"
		if is_available_url $_url || { sleep 1; is_available_url $_url; }; then
			cat <<-REPO >$repodir/$_name.repo
			[$_name]
			name=$_name
			baseurl=$_url
			enabled=1
			gpgcheck=0
			skip_if_unavailable=1
			sslverify=0
			metadata_expire=7d
			REPO
		else
			echo -e "\033[31m[VM:WARN] this url not available: $_url\033[0m" >&2
			continue
		fi
	done
}

#__main__
ENABLE_NRESTRAINT=yes
rpm -q restraint| grep tcler || ENABLE_NRESTRAINT=no

if [[ -f /run/ostree-booted ]]; then
	echo "{warn} already in image mode. nothing-todo" >&2
	exit
fi

pkgs=jq,skopeo,podman
rpm -q ${pkgs//,/ } || yum install -y jq skopeo podman

KOPTS=$(echo "${KOPTS}" | jq -R 'split(" ") | map(select(. != ""))' | tr -d '\n[]')

# update test sript to tmp file
###############################################################################################################
# check whether using self Container or redhat offic bootc image
retryOpt=
arch_info=
imageUrl=docker://images.paas.redhat.com/bootc/rhel-bootc:"$BOOTC_TO"
skopeo inspect -h|grep -q .--retry-times && retryOpt+="--retry-times 60 "
skopeo inspect -h|grep -q .--retry-delay && retryOpt+="--retry-delay 10s"

redhat_compose_id=$(skopeo inspect --insecure-policy $retryOpt --format '{{index .Labels "redhat.compose-id"}}' "$imageUrl")
arch_info=$(skopeo inspect --insecure-policy $retryOpt --format '{{.Architecture}}' "$imageUrl")
if [[ -z ${redhat_compose_id} ]] || [[ -z ${arch_info} ]]; then
	echo "failed to parse images.paas.redhat.com/bootc/rhel-bootc:'${BOOTC_TO}'"
	exit 1
fi

compose_info=${redhat_compose_id}-${arch_info} # eg: RHEL-9.6.0-20250325.3-arm64
echo "redhat_compose from ${imageUrl} is: ${compose_info}"
BOOTC_TO=${compose_info}
MYIMAGE=mybootc:${BOOTC_TO}

mkdir -p repo
ARCH=$(arch_translate "$arch_info")
gen_repos "$BOOTC_TO" ${ARCH} repo

# after bootc install and reboot, Time jumped backwards print on system log
systemctl start chronyd
for ((i=1;i<=3;i++)); do
	chronyc waitsync 10
	((i++))
done
systemctl stop chronyd
hwclock --systohc

#current system root passwd
PWD_HASH=$(sudo grep ^root: /etc/shadow | cut -d: -f2)
echo "got hash from host：$PWD_HASH"
/usr/bin/cp -rf /etc/{fstab,resolv.conf} /usr/bin/brewinstall.sh /bin/kiss-update.sh ./

# Error: creating build container: initializing source docker://images.paas.redhat.com/bootc/rhel-bootc:RHEL-10.0-20250320.8-amd64:
# pinging container registry images.paas.redhat.com: Get "https://images.paas.redhat.com/v2/": net/http: TLS handshake timeout
podman build \
	--tls-verify=false \
	--build-arg BOOTC_TO="$BOOTC_TO" \
	--build-arg PKGS="$PKGS" \
	--build-arg BPKGS="$BPKGS" \
	--build-arg ScriptUrl="$ScriptUrl" \
	--build-arg CMDL="$CMDL" \
	--build-arg PWD_HASH="$PWD_HASH" \
	--build-arg REPOS="$REPOS" \
	--build-arg KOPTS="$KOPTS" \
	--security-opt=label=type:container_runtime_t \
	--cap-add=ALL \
	--no-cache \
	-t localhost/$MYIMAGE \
	-f - . < <(genContainerfile)
bootc_install
