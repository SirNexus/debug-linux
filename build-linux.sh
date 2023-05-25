#!/bin/bash

if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == "0" ]; then
    echo "virtualization not supported. Exiting"
    exit 1
done

if [ -z $(kvm-ok | grep "can be used" )]; then
    echo "kvm acceleration cannot be used"
done

if ! file ~/.ssh/id_rsa.pub; then
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ""
done

sudo apt update
sudo apt install -y qemu-kvm virt-manager virtinst libvirt-clients bridge-utils libvirt-daemon-system \
    gcc pkg-config flex bison libssl-dev libelf-dev dwarves kmod cpio

# Install packer
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo systemctl status libvirtd

sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER

cp config ./linux/.config
make -C linux -j16
mkdir -p ~/.config/gdb/
echo "add-auto-load-safe-path $PWD/linux/scripts/gdb/vmlinux-gdb.py" >> ~/.config/gdb/gdbinit

qemu-img create -F qcow2 -b output/ubuntu-2204/ubuntu-2204.qcow2 -f qcow2 img.qcow2