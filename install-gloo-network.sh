#!/bin/bash

sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc \
    make \
    git \
    pkg-config \
    libelf-dev \
    wget \
    bpftool \
    lsb-release \
    software-properties-common \
    gnupg

echo "export PATH=$PATH:/usr/sbin:/usr/lib/llvm-14/bin" >> ~/.bash_profile

# llc, clang
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 14

echo "Using gh client to authorize instance"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
echo "Authenticating with GitHub (So we can clone private solo projects)"
echo "You will most likely need to select the 'Generate a new SSH key to add to your GitHub account' option and have it upload to your GH account"
gh auth login -w -p ssh
git clone git@github.com:solo-io/gloo-network-agent.git

cd gloo-network-agent

git clone https://github.com/libbpf/libbpf -b v0.8.0 && \
    cd libbpf/src && \
    make all OBJDIR=. && \
    mkdir -p build && \
    make install_headers DESTDIR=build OBJDIR=.;