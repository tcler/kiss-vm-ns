# All files in this dir come from https://github.com/kholia/OSX-KVM

## here, we assuming the macOS-kvm-utils directory has been installed to /usr/share
eval img_download_dir=~/myimages/download
macos_release=high-sierra   #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=mojave        #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=catalina      #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=big-sur       #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=monterey      #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=catalina-bookpro-2013-13inch  #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_release=catalina-bookpro-2013-15inch  #availables: high-sierra, mojave, catalina, big-sur, monterey
macos_vmname=macos-${macos_release}-x
mkdir -p $img_download_dir

macos_image=BaseSystem-mac-$macos_release

#if [[ ! -f $img_download_dir/${macos_image}.img ]]; then
	/usr/share/macOS-kvm-utils/fetch-macOS-v2.py -o $img_download_dir -n ${macos_image} -s $macos_release
	command -v dmg2img || { echo "{ERROR} command dmg2img is required."; exit 1; }
	(cd $img_download_dir; dmg2img -i ${macos_image}.dmg)
#fi

macos_image_path=$img_download_dir/${macos_image}.img

#note1: --virt-install-opts=--controller=type=usb,model=none is for avoid controller conflict
#note2: address.bus=0x00,address.slot=0x0a, because if bus!=0x00 the nic will not be recognized
#note3: qemu-options come from https://github.com/kholia/OSX-KVM/blob/master/macOS-libvirt-Catalina.xml
vm create macOS \
	-n $macos_vmname \
	--machine q35 \
	--osv $(osinfo-query os|awk '/macos/{osv=$1} END{print osv}') \
	--boot loader=/usr/share/macOS-kvm-utils/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash,nvram=/usr/share/macOS-kvm-utils/OVMF_VARS-1024x768.fd \
	-F /usr/share/macOS-kvm-utils/OpenCore.qcow2 \
	--disk $macos_image_path \
	--qemu-opts "-device isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
	--qemu-opts "-smbios type=2  -usb -device usb-tablet -device usb-kbd" \
	--qemu-opts "-cpu host,vendor=GenuineIntel,+hypervisor,+invtsc,kvm=on,+fma,+avx,+avx2,+aes,+ssse3,+sse4_2,+popcnt,+sse4a,+bmi1,+bmi2" \
	--net=default,model=vmxnet3,address.type=pci,address.bus=0x00,address.slot=0x0a \
	--virt-install-opts=--controller=type=usb,model=none \
	--msize 8192 \
	--dsize 128 \
	--diskbus sata \
	--noauto --force --vncwait="...,key:right key:enter"
