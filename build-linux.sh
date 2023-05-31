#!/bin/bash

set -x

git submodule update --init

if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == "0" ]; then
    echo "virtualization not supported. Exiting"
    exit 1
fi

sudo apt install -y cpu-checker

if [ -z $(kvm-ok | grep "can be used" )]; then
    echo "kvm acceleration cannot be used"
fi

if ! ls ~/.ssh/id_rsa.pub; then
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ""
fi

sudo apt update
sudo apt install -y qemu-kvm virt-manager virtinst libvirt-clients bridge-utils libvirt-daemon-system \
    gcc pkg-config flex bison libssl-dev libelf-dev dwarves kmod cpio \
    gdb

# Install packer
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y packer

sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo systemctl status libvirtd

sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
sudo su $USER

packer build ubuntu.pkr.hcl

cp config ./linux/.config
make -C linux -j16
mkdir -p ~/.config/gdb/
echo "add-auto-load-safe-path $PWD/linux/scripts/gdb/vmlinux-gdb.py" >> ~/.config/gdb/gdbinit

qemu-img create -F qcow2 -b output/ubuntu-2204/ubuntu-2204.qcow2 -f qcow2 img.qcow2

qemu-system-x86_64 \
  -kernel ./linux/arch/x86/boot/bzImage \
  -serial mon:stdio \
  -drive file=img.qcow2,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
  -net nic -net user,hostfwd=tcp::10022-:22 \
  -m 16384 -nographic \
  -append "root=/dev/vda2 ro rdinit=/sbin/init net.ifnames=0 biosdevname=0 console=ttyS0 nokaslr" \
  -virtfs local,path=$HOME,mount_tag=host0,security_model=mapped,id=host0 \
  -smp 32 \
  -s