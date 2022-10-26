#!/bin/sh

set -eu

# FIXME(cole-h): shift arg indexes once everything has been tested to work
CONFIG_ARCH=$4 # arm64 or x86_64
CONFIG_FLAKE_URI=$5

#set -x

while ! ping -c1 nixos.org; do
    sleep 1
done

export HOME=/root

# mostly from darwin-installer: https://github.com/LnL7/nix-darwin/blob/d3d7db7b86c8a2f3fa9925fe5d38d29025e7cb7f/pkgs/darwin-installer/installer.nix#L40-L48
if ! grep -q '^run\b' /etc/synthetic.conf 2>/dev/null; then
    printf "run\tprivate/var/run\n" | sudo tee -a /etc/synthetic.conf >/dev/null
    /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B &>/dev/null || true
    /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t &>/dev/null || true
fi

if [ ! -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    #curl -L -o install.xz https://hydra.nixos.org/job/nix/master/binaryTarball.aarch64-darwin/latest/download/1
    #tar -xf install.xz
    #cd nix-*
    
    curl -Lo install https://nixos.org/nix/install
    time sh ./install --daemon 2>&1 | tail -n5
fi

if ! hash nix; then
    set +eux
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    set -eux
fi

if [ ! -d /nix/home ]; then
    mkdir -p /nix/home
fi

export HOME=/nix/home

# TODO(cole-h): maybe make the ref configurable as well? have to see if darwin-
# rebuild accepts `darwinConfigurations.asdf` instead of just `asdf`
nix --extra-experimental-features 'nix-command flakes' build "$CONFIG_FLAKE_URI"#darwinConfigurations."$CONFIG_ARCH".system

sudo rm /etc/nix/nix.conf || true

./result/sw/bin/darwin-rebuild switch --flake "$CONFIG_FLAKE_URI"#"$CONFIG_ARCH"
unlink ./result

echo "Done!"
