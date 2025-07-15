
echo 'LIBVIRTD_ARGS="-l"' >/etc/sysconfig/libvirtd
grep -q ^listen_tls.-.0 || cat <<EOF >>/etc/libvirt/libvirtd.conf
listen_tls = 0
listen_tcp = 1
#listen_addr = ""
tcp_port = "16509"
auth_unix_ro = "none"
auth_unix_rw = "none"
auth_tcp = "none"
log_level = 3
EOF

systemctl mask libvirtd.socket libvirtd-ro.socket \
	libvirtd-admin.socket libvirtd-tls.socket libvirtd-tcp.socket

systemctl restart libvirtd

ss -atnl | grep 16509

: <<COMM
jiyin@x99i:~$ virsh -c test+tcp://10.73.180.96/default list
 Id   名称   状态
-------------------
 1    test   运行

jiyin@x99i:~$ virsh -c qemu+tcp://10.73.180.96/system list
 Id   名称                状态
--------------------------------
 1    rdma-lab0-vm-49-0   运行
 2    rdma-lab0-vm-49-1   运行
 3    rdma-lab0-vm-49-2   运行
 4    rdma-lab0-vm-49-3   运行
 5    rdma-lab0-vm-49-4   运行
 6    rdma-lab0-vm-49-5   运行
 7    rdma-lab0-vm-49-6   运行
 8    rdma-lab0-vm-49-7   运行
 9    rdma-lab0-vm-49-8   运行
 10   rdma-lab0-vm-49-9   运行

jiyin@x99i:~$ LANG=C virsh -c qemu+tcp://dell-per750-49.rhts.eng.pek2.redhat.com/system console rdma-lab0-vm-49-0
Connected to domain 'rdma-lab0-vm-49-0'
Escape character is ^] (Ctrl + ])

[root@rdma-lab0-vm-49-0 ~]# uname -r
5.14.0-598.el9.x86_64

jiyin@x99i:~$ LANG=C virsh -c qemu+tcp://dell-per750-49.rhts.eng.pek2.redhat.com/system list
 Id   Name                State
-----------------------------------
 1    rdma-lab0-vm-49-0   running
 2    rdma-lab0-vm-49-1   running
 3    rdma-lab0-vm-49-2   running
 4    rdma-lab0-vm-49-3   running
 5    rdma-lab0-vm-49-4   running
 6    rdma-lab0-vm-49-5   running
 7    rdma-lab0-vm-49-6   running
 8    rdma-lab0-vm-49-7   running
 9    rdma-lab0-vm-49-8   running
 10   rdma-lab0-vm-49-9   running
COMM
