declare -A distroInfo

#### CentOS stream and CentOS
distroInfo[CentOS-8-stream]="https://cloud.centos.org/centos/8-stream/x86_64/images/ http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/"
distroInfo[CentOS-8]="https://cloud.centos.org/centos/8/x86_64/images/ http://mirror.centos.org/centos/8/BaseOS/x86_64/os/"
distroInfo[CentOS-7]="https://cloud.centos.org/centos/7/images/%%GenericCloud-.{4}.qcow2c http://mirror.centos.org/centos/7/os/x86_64/"
distroInfo[CentOS-6]="https://cloud.centos.org/centos/6/images/%%GenericCloud.qcow2c http://mirror.centos.org/centos/6/os/x86_64/"

#### Fedora
# https://ord.mirror.rackspace.com/fedora/releases/$version/Cloud/
distroInfo[fedora-rawhide]="https://ord.mirror.rackspace.com/fedora/development/rawhide/Cloud/x86_64/images/"
distroInfo[fedora-34]="https://ord.mirror.rackspace.com/fedora/releases/34/Cloud/x86_64/images/"
distroInfo[fedora-33]="https://ord.mirror.rackspace.com/fedora/releases/33/Cloud/x86_64/images/"
distroInfo[fedora-32]="https://ord.mirror.rackspace.com/fedora/releases/32/Cloud/x86_64/images/"
distroInfo[fedora-31]="https://ord.mirror.rackspace.com/fedora/releases/31/Cloud/x86_64/images/"
distroInfo[fedora-30]="https://ord.mirror.rackspace.com/fedora/releases/30/Cloud/x86_64/images/"
distroInfo[fedora-29]="https://ord.mirror.rackspace.com/fedora/releases/29/Cloud/x86_64/images/"

#### Debian
# https://cdimage.debian.org/cdimage/openstack/testing/
# https://cdimage.debian.org/cdimage/openstack/$latestVersion/
# https://cdimage.debian.org/cdimage/openstack/archive/$olderVersion/
distroInfo[debian-testing]="https://cdimage.debian.org/cdimage/openstack/testing/debian-testing-openstack-amd64.qcow2"
distroInfo[debian-10]="https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2"
distroInfo[debian-9]="https://cdimage.debian.org/cdimage/openstack/current-9/debian-9-openstack-amd64.qcow2"

#### OpenSUSE
distroInfo[openSUSE-leap-15.2]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.2/images/openSUSE-Leap-15.2-OpenStack.x86_64.qcow2"

#### FreeBSD
distroInfo[FreeBSD-12.2]="https://download.freebsd.org/ftp/releases/VM-IMAGES/12.2-RELEASE/amd64/Latest/FreeBSD-12.2-RELEASE-amd64.qcow2.xz"
distroInfo[FreeBSD-13.0]="https://download.freebsd.org/ftp/releases/VM-IMAGES/13.0-RELEASE/amd64/Latest/FreeBSD-13.0-RELEASE-amd64.qcow2.xz"
distroInfo[FreeBSD-14.0]="https://download.freebsd.org/ftp/snapshots/VM-IMAGES/14.0-CURRENT/amd64/Latest/FreeBSD-14.0-CURRENT-amd64.qcow2.xz"

#### ArchLinux
distroInfo[archlinux]="https://linuximages.de/openstack/arch/arch-openstack-LATEST-image-bootstrap.qcow2"
