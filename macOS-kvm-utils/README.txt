# ------------------------------------------------------------------------------
# All files in this dir come from https://github.com/kholia/OSX-KVM
# I just tried converting the xml template macOS-libvirt-Catalina.xml
# into command line arguments for virt-install/kiss-vm, thus simplifying the
# steps of making macOS-in-KVM
#
# And this README.txt is also a valid bash script, you can run it:
#   bash /path/to/README.txt
# after installed kiss-vm: https://github.com/tcler/kiss-vm-ns
#-------------------------------------------------------------------------------

## here, we assuming the macOS-kvm-utils directory has been installed to /usr/share
eval img_download_dir=~/myimages/download

macos_release=high-sierra   #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=mojave        #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=catalina      #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=catalina-bookpro-2013-13inch  #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=catalina-bookpro-2013-15inch  #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=big-sur       #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=monterey      #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura
macos_release=ventura       #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura

macos_release=catalina      #availables: high-sierra, mojave, catalina, big-sur, monterey, ventura

macos_vmname=macos-${macos_release}
macos_image=BaseSystem-mac-$macos_release

mkdir -p $img_download_dir
if [[ ! -f $img_download_dir/${macos_image}.img ]]; then
	/usr/share/macOS-kvm-utils/fetch-macOS-v2.py -o $img_download_dir -n ${macos_image} -s $macos_release -v
	command -v dmg2img || { echo "{ERROR} command dmg2img is required."; exit 1; }
	(cd $img_download_dir; dmg2img -i ${macos_image}.dmg)
fi

macos_image_path=$img_download_dir/${macos_image}.img

#qemu cpu options
cpu_vendor=$(awk '/vendor_id/{print $NF; exit}' /proc/cpuinfo)
case $cpu_vendor in
*Intel)
	#verified on host(thindpad-T460P: {CPU: Intel i7-6700HQ, OS: fedora-37}) with all macOS version
	qemucpu_opt="-cpu host,vendor=GenuineIntel,+hypervisor,+invtsc,kvm=on,+fma,+avx,+avx2,+aes,+ssse3,+sse4_2,+popcnt,+sse4a,+bmi1,+bmi2";;
*AMD)
	#verified on host(deskmini-x300: {CPU: AMD R7-5700G, OS: fedora-36}) with high-sierra,catalina,big-sur
	#yes, we need emulate Intel CPU on AMD cpu. here we use model: Haswell[2013](or Broadwell[2015]) for better compatible
	qemucpu_opt="-cpu Haswell,vendor=GenuineIntel,+hypervisor,+invtsc,kvm=on,+fma,+avx,+avx2,+aes,+ssse3,+sse4_2,+popcnt,+sse4a,+bmi1,+bmi2";;
esac

#note1: --virt-install-opts=--controller=type=usb,model=none is for avoid controller conflict
#note2: address.bus=0x00,address.slot=0x0a, because if bus!=0x00 the nic will not be recognized
#note3: qemu-options come from https://github.com/kholia/OSX-KVM/blob/master/macOS-libvirt-Catalina.xml
vm create macOS -n $macos_vmname \
	--machine q35 \
	--osv $(osinfo-query os|awk '/macos/{osv=$1} END{print osv}') \
	--boot loader=/usr/share/macOS-kvm-utils/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash,nvram=/usr/share/macOS-kvm-utils/OVMF_VARS-1024x768.fd \
	-F /usr/share/macOS-kvm-utils/OpenCore.qcow2 \
	--disk $macos_image_path \
	--qemu-opts "-device isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
	--qemu-opts "-smbios type=2  -usb -device usb-tablet -device usb-kbd" \
	--qemu-opts "${qemucpu_opt}" \
	--net=default,model=vmxnet3,address.type=pci,address.bus=0x00,address.slot=0x0a \
	--virt-install-opts=--controller=type=usb,model=none \
	--msize 8192 \
	--dsize 128 \
	--diskbus sata \
	--noauto --force --vncwait="...,key:right key:enter"
	#--hostdev <pci_addr> if want passthru host device into VM, add this option
	#you could get iommu-group info by using command: iommu-groups.sh

#note4: see: https://www.quora.com/What-should-I-do-if-my-MacBook-is-stuck-on-Less-than-a-minute-remaining-updating-Big-Sur
#note4: if get stuck on "Less than a minute remaining", just reboot. and most of the time, the problem will be solved.
#note4:   vm reboot $vmname; vm viewer $vmname
