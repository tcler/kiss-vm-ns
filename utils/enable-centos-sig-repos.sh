#!/bin/bash
# Enable commonly used SIG repositories for development/testing environment
# thanks deepseek

enable_centos_sig_repos_for_dev() {
	local hyperscale=no ganeshaver=9
	for arg; do
		case $arg in
		+hyp*) hyperscale=yes;;
		ganesha=[0-9]*) ganeshaver=${arg#*=};;
		esac
	done
	. /etc/os-release

	# Determine repositories based on distribution and version
	case "$ID" in
	rhel|centos|rocky|almalinux)
		major_version=$(echo "$VERSION_ID" | cut -d. -f1)

		# 0. Enable PowerTools/CRB for dependencies
		if [[ "$major_version" == "8" ]]; then
			dnf config-manager --set-enabled powertools
		elif [[ "$major_version" == "9" ]]; then
			dnf config-manager --set-enabled crb
		fi

		# 1. Storage SIG - NFS-Ganesha 5.x (primary target)
		echo "Enabling Storage SIG for NFS-Ganesha 5..."
		if [[ "$ID" =~ ^(rocky|almalinux)$ ]]; then
			# Rocky/Alma: add repo manually
			cat > /etc/yum.repos.d/CentOS-NFS-Ganesha-5.repo <<-EOF
			[centos-nfs-ganesha${ganeshaver}]
			name=CentOS-\$releasever - NFS Ganesha ${ganeshaver}
			baseurl=https://buildlogs.centos.org/centos/${major_version}-stream/storage/x86_64/nfsganesha-${ganeshaver}/
			gpgcheck=0
			enabled=1
			EOF
		else
			dnf install -y centos-release-nfs-ganesha5
		fi

		# 2. Storage SIG - GlusterFS (optional, for testing GlusterFS backend)
		echo "Enabling Storage SIG for GlusterFS..."
		if [[ "$major_version" == "8" ]]; then
			dnf install -y centos-release-gluster8
		elif [[ "$major_version" == "9" ]]; then
			dnf install -y centos-release-gluster9 2>/dev/null || \
				echo "GlusterFS 9 not available, skipping"
		fi

		# 3. Cloud SIG - OpenStack (optional, for cloud development)
		echo "Enabling Cloud SIG for OpenStack..."
		if [[ "$major_version" == "8" ]]; then
			dnf install -y centos-release-openstack-zed
		elif [[ "$major_version" == "9" ]]; then
			dnf install -y centos-release-openstack-epoxy
		fi

		# 4. Hyperscale SIG (optional, for performance optimization)
		# NOTE: This SIG replaces core system components (kernel, systemd)
		# Only enable when explicitly needed
		[[ "$hyperscale" = yes ]] &&
			dnf install -y centos-release-hyperscale

		# Update cache
		dnf makecache

		echo "All SIG repositories enabled successfully"
		;;
	fedora)
		echo "Fedora detected - official repos already include most packages"
		;;
	*)
		echo "Unsupported distribution: $ID"
		return 1
		;;
	esac
}

# Execute the function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	enable_centos_sig_repos_for_dev "${@}"
fi
