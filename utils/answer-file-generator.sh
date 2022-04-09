#!/bin/bash

LANG=C
PROG=${0}; [[ $0 = /* ]] && PROG=${0##*/}

SUDOUSER=${SUDO_USER:-$(whoami)}
eval SUDOUSERHOME=~$SUDOUSER

# ==============================================================================
# Parameter Processing
# ==============================================================================
Usage() {
cat <<EOF
Usage: $PROG [OPTIONS]

Options for windows anwserfile:
  --temp[=<base|cifs-nfs|addsdomain|addsforest>]
		#name of answer file's template, default: base
		 see also: /usr/share/AnswerFileTemplates/$template_name/
  --uefi        #uefi partition
  --hostname    #hostname of Windows Guest VM; e.g: win2019-ad
  --domain <domain>
		#*Specify windows domain name; e.g: qetest.org

  --locale <local>
		#default en-US. see also: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11
  -u, --user <user>
		#Specify user for install and config.
		  default value: Administrator
  -p, --password <password>
		#*Specify user's password for windows. for configure AD/DC:
		  must use a mix of uppercase letters, lowercase letters, numbers, and symbols
		  default value: Sesame~0pen

  --path <answer file image path>
		#e.g: --path /path/to/ansf-usb.image
  --wim-index <wim image index>
  --product-key #Prodcut key for windows activation.

  --ad-forest-level <Default|Win2008|Win2008R2|Win2012|Win2012R2|WinThreshold>
		#Specify active directory forest level.
		  Windows Server 2003: 2 or Win2003
		  Windows Server 2008: 3 or Win2008
		  Windows Server 2008 R2: 4 or Win2008R2
		  Windows Server 2012: 5 or Win2012
		  Windows Server 2012 R2: 6 or Win2012R2
		  Windows Server 2016: 7 or WinThreshold
		#The default forest functional level in Windows Server is typically the same -
		#as the version you are running. However, the default forest functional level -
		#in Windows Server 2008 R2 when you create a new forest is Windows Server 2003 or 2.
		#see: https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest?view=win10-ps
  --ad-domain-level <Default|Win2008|Win2008R2|Win2012|Win2012R2|WinThreshold>
		#Specify active directory domain level.
		  Windows Server 2003: 2 or Win2003
		  Windows Server 2008: 3 or Win2008
		  Windows Server 2008 R2: 4 or Win2008R2
		  Windows Server 2012: 5 or Win2012
		  Windows Server 2012 R2: 6 or Win2012R2
		  Windows Server 2016: 7 or WinThreshold
		#The domain functional level cannot be lower than the forest functional level,
		#but it can be higher. The default is automatically computed and set.
		#see: https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest?view=win10-ps
  --enable-kdc  #enable AD KDC service(in case use AnswerFileTemplates/cifs-nfs/postinstall.ps1)
		#- to do nfs/cifs krb5 test
  --parent-domain <parent-domain>
		#Domain name of an existing domain, only for template: 'addsdomain'
  --parent-ip <parent-ip>
		#IP address of an existing domain, only for template: 'addsdomain'
  --dfs-target <server:sharename>
		#The specified cifs share will be added into dfs target.
  --openssh <url|local_path>
		#url/path to download/copy OpenSSH-Win64.zip
  --virtio-win <url|local_path>
		#url/path to download/copy virtio-win.iso
  --driver-url,--download-url <url|local_path>
		#url to download extra drivers to anserfile media:
		#e.g: --driver-url=urlX --driver-url=urlY
  --run,--run-with-reboot <command line>
		#powershell cmd line need autorun and reboot
		#e.g: --run='./MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe /S /V"qb /norestart"'
  --run-post <command line>
		#powershell cmd line need autorun without reboot
		#e.g: --run-post='ipconfig /all; ibstat'
  --mac-ext <mac-addr>
		#set mac addr for the nic that connect to public network
  --mac-int <mac-addr>
		#set mac addr for the nic that connect to internal libvirt network
  --static-ip-ext <>
		#set static ip for the nic that connect to public network
  --static-ip-int <>
		#set static ip for the nic that connect to internal libvirt network

Examples:
  #create answer file usb for Active Directory forest Win2012r2:
  read macin macex _ < <(gen-virt-mac.sh 2)
  $PROG --hostname win2012-adf --domain ad.test   --product-key "$key" \\
	-p ~Ocgxyz --ad-forest-level Win2012R2 \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--mac-int=$macin --mac-ext=$macex
	--temp=addsforest --path ./ansf-usb.image
  vm create Windows-Server-2012 -n win2012-adf -C ~/Downloads/Win2012r2-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=e1000,mac=$macin --net-macvtap=-,model=e1000,mac=$macex \\
	--diskbus sata

  #create answer file usb for Active Directory child domain:
  read macin macex _ < <(gen-virt-mac.sh 2)
  $PROG --hostname win2016-adc --domain fs.qe \\
	-p ~Ocgxyz --parent-domain kernel.test --parent-ip \$addr \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--mac-int=$macin --mac-ext=$macex
	--temp=addsdomain --path ./ansf-usb.image
  vm create Windows-Server-2016 -n win2016-adc -C ~/Downloads/Win2016-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=e1000,mac=$macin --net-macvtap=-,model=e1000,mac=$macex \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and enable KDC(--enable-kdc):
  read macin macex _ < <(gen-virt-mac.sh 2)
  $PROG --hostname win2019-nfs --domain cifs-nfs.test \\
	-p ~Ocgxyz --enable-kdc \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--mac-int=$macin --mac-ext=$macex
	--temp=cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-nfs -C ~/Downloads/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=e1000,mac=$macin --net-macvtap=-,model=e1000,mac=$macex \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and install mellanox driver:
  read macin macex _ < <(gen-virt-mac.sh 2)
  $PROG --hostname win2019-rdma --domain nfs-rdma.test \\
	-p ~Ocgxyz \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--mac-int=$macin --mac-ext=$macex
	--driver-url=http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe \\
	--run-with-reboot='./MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe /S /V\"/qb /norestart\"' \\
	--run-post='ipconfig /all; ibstat' \\
	--temp=cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-rdma -C ~/Downloads/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=e1000,mac=$macin --net-macvtap=-,model=e1000,mac=$macex \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and add dfs target, and enable KDC(--enable-kdc):
  read macin macex _ < <(gen-virt-mac.sh 2)
  $PROG --hostname win2019-dfs --domain cifs-nfs.test \\
	-p ~Ocgxyz --dfs-target \$hostname:\$cifsshare --enable-kdc \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--mac-int=$macin --mac-ext=$macex
	--temp=cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-dfs -C ~/Downloads/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=e1000,mac=$macin --net-macvtap=-,model=e1000,mac=$macex \\
	--diskbus sata

EOF
}

ARGS=$(getopt -o hu:p: \
	--long help \
	--long temp:: \
	--long uefi \
	--long path: \
	--long user: \
	--long password: \
	--long wim-index: \
	--long product-key: \
	--long hostname: \
	--long locale: \
	--long domain: \
	--long ad-forest-level: \
	--long ad-domain-level: \
	--long mac-ext: \
	--long mac-int: \
	--long static-ip-ext: \
	--long static-ip-int: \
	--long enable-kdc \
	--long parent-domain: \
	--long parent-ip: \
	--long openssh: \
	--long virtio-win: \
	--long driver-url: --long download-url: \
	--long run: --long run-with-reboot: \
	--long run-post: \
	--long dfs-target: \
	-a -n "$PROG" -- "$@")
eval set -- "$ARGS"
while true; do
	case "$1" in
	-h|--help) Usage; exit 1;; 
	--temp) TEMPLATE=${2:-base}; shift 2;;
	--uefi) UEFI=yes; shift 1;;
	--path) ANSF_IMG_PATH="$2"; shift 2;;
	-u|--user) ADMINUSER="$2"; shift 2;;
	-p|password) ADMINPASSWORD="$2"; shift 2;;
	--wim-index) WIM_IMAGE_INDEX="$2"; shift 2;;
	--product-key) PRODUCT_KEY="$2"; shift 2;;
	--hostname) GUEST_HOSTNAME="$2"; shift 2;;
	--locale) LOCALE="$2"; shift 2;;
	--domain) DOMAIN="$2"; shift 2;;
	--ad-forest-level) AD_FOREST_LEVEL="$2"; shift 2;;
	--ad-domain-level) AD_DOMAIN_LEVEL="$2"; shift 2;;
	--mac-ext) MAC_EXT="$2"; shift 2;;
	--mac-int) MAC_INT="$2"; shift 2;;
	--static-ip-ext) STATIC_IP_EXT="$2"; shift 2;;
	--static-ip-int) STATIC_IP_INT="$2"; shift 2;;
	--enable-kdc) KDC_OPT="-kdc"; shift 1;;
	--parent-domain) PARENT_DOMAIN="$2"; shift 2;;
	--parent-ip) PARENT_IP="$2"; shift 2;;
	--openssh) OpenSSHUrl="$2"; shift 2;;
	--virtio-win) VirtioDriverISOUrl="$2"; shift 2;;
	--driver-url|--download-url) DL_URLS+=("$2"); shift 2;;
	--run|--run-with-reboot) RUN_CMDS+=("$2"); shift 2;;
	--run-post) RUN_POST_CMDS+=("$2"); shift 2;;
	--dfs-target) DFS_TARGET="$2"; DFS=yes; shift 2;;
	--) shift; break;;
	*) Usage; exit 1;; 
	esac
done

OpenSSHUrl=${OpenSSHUrl:-https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip}
: <<EOF
if [[ -z "$VirtioDriverISOUrl" ]]; then
	VirtioDriverISOUrl=/usr/share/virtio-win/virtio-win.iso
	if [[ ! -f "$VirtioDriverISOUrl" ]]; then
		VirtioDriverISOUrl=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.215-2/virtio-win.iso
		#^^ fixme: auto get latest version instead hard-code
	fi
fi
EOF

AD_FOREST_LEVEL=${AD_FOREST_LEVEL:-Default}
AD_DOMAIN_LEVEL=${AD_DOMAIN_LEVEL:-$AD_FOREST_LEVEL}
AnserfileTemplatesRepo=${AnserfileTemplatesRepo:-/usr/share/AnswerFileTemplates}
TemplateDir=$AnserfileTemplatesRepo/$TEMPLATE
if [[ ! -d "$TemplateDir" ]]; then
	echo "{ERROR} answerfile template dir($TemplateDir) not found" >&2
	exit 1
fi

if egrep -q "@PARENT_(DOMAIN|IP)@" -r "$TemplateDir"; then
	[[ -z "$PARENT_DOMAIN" || -z "$PARENT_IP" ]] && {
		echo "{ERROR} Missing parent-domain or parent-ip for template(${TemplateDir##*/})" >&2
		Usage >&2
		exit 1
	}
fi

[[ -z "$PRODUCT_KEY" ]] && {
	echo -e "{WARN} *** There is no Product Key specified, We assume that you are using evaluation version."
	echo -e "{WARN} *** Otherwise please use the '--product-key <key>' to ensure successful installation."
}

curl_download() {
	local filename=$1
	local url=$2
	shift 2;

	local curlopts="-f -L"
	local header=
	local fsizer=1
	local fsizel=0
	local rc=

	[[ -z "$filename" || -z "$url" ]] && {
		echo "Usage: curl_download <filename> <url> [curl options]" >&2
		return 1
	}

	header=$(curl -L -I -s $url|sed 's/\r//')
	fsizer=$(echo "$header"|awk '/Content-Length:/ {print $2; exit}')
	if echo "$header"|grep -q 'Accept-Ranges: bytes'; then
		curlopts+=' --continue-at -'
	fi

	echo "{INFO} run: curl -o $filename ${url} $curlopts $curlOpt $@"
	curl -o $filename $url $curlopts $curlOpt "$@"
	rc=$?
	if [[ $rc != 0 && -s $filename ]]; then
		fsizel=$(stat --printf %s $filename)
		if [[ $fsizer -le $fsizel ]]; then
			echo "{INFO} *** '$filename' already exist $fsizel/$fsizer"
			rc=0
		fi
	fi

	return $rc
}
curl_download_x() { until curl_download "$@"; do sleep 1; done; }

getDefaultIp4() {
	local nic=$1
	[[ -z "$nic" ]] &&
		nics=$(ip route | awk '/default/{match($0,"dev ([^ ]+)",M); print M[1]}')
	for nic in $nics; do
		[[ -z "$(ip -d link show  dev $nic|sed -n 3p)" ]] && {
			break
		}
	done
	local ipaddr=$(ip addr show $nic)
	local ret=$(echo "$ipaddr" |
		awk '/inet .* (global|host lo)/{match($0,"inet ([0-9.]+)",M); print M[1]}')
	echo "$ret"
}

# =======================================================================
# Global variable
# =======================================================================
IPCONFIG_LOGF=ipconfig.log
INSTALL_COMPLETE_FILE=installcomplete
POST_INSTALL_LOGF=postinstall.log
VIRTHOST=$(
for H in $(hostname -A); do
	if [[ ${#H} > 15 && $H = *.*.* ]]; then
		echo $H;
		break;
	fi
done)
[[ -z "$VIRTHOST" ]] && {
	_ipaddr=$(getDefaultIp4)
	VIRTHOST=$(host ${_ipaddr%/*} | awk '{print $NF; exit}')
	VIRTHOST=${VIRTHOST%.}
	[[ "$VIRTHOST" = *NXDOMAIN* ]] && {
		VIRTHOST=$_ipaddr
	}
}

# =======================================================================
# Windows Preparation
# =======================================================================
LOCALE=${LOCALE:-en-US}
WIM_IMAGE_INDEX=${WIM_IMAGE_INDEX:-4}
[[ "$VM_OS_VARIANT" = win10 ]] && WIM_IMAGE_INDEX=1
GUEST_HOSTNAME=${GUEST_HOSTNAME}
[[ -z "$GUEST_HOSTNAME" ]] && {
	echo -e "{ERROR} you are missing --hostname=<vm-hostname> option, it is necessary" >&2
	Usage >&2
	exit 1
}
[[ ${#GUEST_HOSTNAME} -gt 15 ]] && {
	echo -e "{ERROR} length of hostname($GUEST_HOSTNAME) should < 16" >&2
	exit 1
}
DOMAIN=${DOMAIN:-winlrn.org}
ADMINUSER=${ADMINUSER:-Administrator}
ADMINPASSWORD=${ADMINPASSWORD:-Sesame~0pen}

# Setup Active Directory
FQDN=$GUEST_HOSTNAME.$DOMAIN
[[ -n "$PARENT_DOMAIN" ]] && FQDN+=.$PARENT_DOMAIN
NETBIOS_NAME=$(echo ${DOMAIN//./} | tr '[a-z]' '[A-Z]')
NETBIOS_NAME=${NETBIOS_NAME:0:15}

# anwser file usb image path ...
ANSF_IMG_PATH=${ANSF_IMG_PATH:-ansf-usb.image}

# ====================================================================
# Generate answerfiles media(USB)
# ====================================================================
process_ansf() {
	local destdir=$1; shift
	for f; do fname=${f##*/}; cp ${f} $destdir/${fname%.in}; done

	sed -i -e "s/@ADMINPASSWORD@/$ADMINPASSWORD/g" \
		-e "s/@ADMINUSER@/$ADMINUSER/g" \
		-e "s/@AD_DOMAIN@/$DOMAIN/g" \
		-e "s/@NETBIOS_NAME@/$NETBIOS_NAME/g" \
		-e "s/@FQDN@/$FQDN/g" \
		-e "s/@PRODUCT_KEY@/$PRODUCT_KEY/g" \
		-e "s/@WIM_IMAGE_INDEX@/$WIM_IMAGE_INDEX/g" \
		-e "s/@ANSF_DRIVE_LETTER@/$ANSF_DRIVE_LETTER/g" \
		-e "s/@INSTALL_COMPLETE_FILE@/$INSTALL_COMPLETE_FILE/g" \
		-e "s/@AD_FOREST_LEVEL@/$AD_FOREST_LEVEL/g" \
		-e "s/@AD_DOMAIN_LEVEL@/$AD_DOMAIN_LEVEL/g" \
		-e "s/@VNIC_MAC_INT@/$MAC_INT/g" \
		-e "s/@VNIC_MAC_EXT@/$MAC_EXT/g" \
		-e "s/@STATIC_IP_INT@/$STATIC_IP_INT/g" \
		-e "s/@STATIC_IP_EXT@/$STATIC_IP_EXT/g" \
		-e "s/@VIRTHOST@/$VIRTHOST/g" \
		-e "s/@IPCONFIG_LOGF@/$IPCONFIG_LOGF/g" \
		-e "s/@GUEST_HOSTNAME@/$GUEST_HOSTNAME/g" \
		-e "s/@POST_INSTALL_LOG@/C:\\\\$POST_INSTALL_LOGF/g" \
		-e "s/@KDC_OPT@/$KDC_OPT/g" \
		-e "s/@PARENT_DOMAIN@/$PARENT_DOMAIN/g" \
		-e "s/@PARENT_IP@/$PARENT_IP/g" \
		-e "s/@DFS_TARGET@/$DFS_TARGET/g" \
		-e "s/@HOST_NAME@/$HOSTNAME/g" \
		-e "s/@AUTORUN_DIR@/$ANSF_AUTORUN_DIR/g" \
		-e "s/@LOCALE@/$LOCALE/g" \
		$destdir/*
	[[ -z "$PRODUCT_KEY" ]] && {
		echo -e "{INFO} remove ProductKey node from xml ..."
		sed -i '/<ProductKey>/ { :loop /<\/ProductKey>/! {N; b loop}; s;<ProductKey>.*</ProductKey>;; }' $destdir/*.xml
	}
	[[ "$UEFI" = yes ]] && {
		echo -e "{INFO} enable UEFI ..."
		sed -i -e '/remove me to enable UEFI/d' -e '/PartitionID/s/1/3/' $destdir/*.xml
	}
	unix2dos $destdir/* >/dev/null

	if [[ -n "$OpenSSHUrl" ]]; then
		[[ -f "$OpenSSHUrl" ]] && OpenSSHUrl=file://$(readlink -f "$OpenSSHUrl")
		curl_download_x $destdir/OpenSSH.zip $OpenSSHUrl
	fi
	if [[ -n "$VirtioDriverISOUrl" ]]; then
		[[ "$VirtioDriverISOUrl" = ~* ]] && eval VirtioDriverISOUrl=$VirtioDriverISOUrl
		[[ -f "$VirtioDriverISOUrl" ]] && VirtioDriverISOUrl=file://$(readlink -f "$VirtioDriverISOUrl")
		curl_download_x $destdir/virtio-win.iso $VirtioDriverISOUrl
	fi
	mkdir $destdir/sshkeys
	cp $SUDOUSERHOME/.ssh/id_*.pub $destdir/sshkeys/. 2>/dev/null

	autorundir=$destdir/$ANSF_AUTORUN_DIR
	if [[ -n "$DL_URLS" ]]; then
		mkdir -p $autorundir
		for _url in "${DL_URLS[@]}"; do
			_fname=${_url##*/}
			[[ -f "$_url" ]] && _url=file://$(readlink -f "$_url")
			curl_download_x $autorundir/${_fname} "$_url"
		done
	fi
	if [[ -n "$RUN_CMDS" || -n "$RUN_POST_CMDS" ]]; then
		mkdir -p $autorundir
		runf=$autorundir/autorun.ps1
		runpostf=$autorundir/autorun-post.ps1
		for _cmd in "${RUN_CMDS[@]}"; do
			echo "$_cmd" >>$runf
		done
		for _cmd in "${RUN_POST_CMDS[@]}"; do
			echo "$_cmd" >>$runpostf
		done
		unix2dos $runf $runpostf >/dev/null
	fi
}

echo -e "\n{INFO} make answer file media ..."
eval "ls $TemplateDir/*" || {
	echo -e "\n{ERROR} answer files not found in $TemplateDir"
	exit 1
}
\rm -f $ANSF_IMG_PATH #remove old/exist media file

ANSF_DRIVE_LETTER="D:"
ANSF_AUTORUN_DIR=tools-drivers
usbSize=1024M
media_dir=$(mktemp -d)
trap "rm -fr $media_dir" EXIT
process_ansf $media_dir $TemplateDir/*
virt-make-fs -s $usbSize -t vfat $media_dir $ANSF_IMG_PATH --partition
