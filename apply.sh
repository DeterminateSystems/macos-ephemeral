#!/bin/sh

set -eu

CONFIG_FLAKE_REF=$1

#set -x

while ! ping -c1 github.com; do
    sleep 1
done

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

    curl -Lo install https://install.determinate.systems/nix
    time sh ./install install --no-confirm 2>&1 | tail -n5
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

nix --extra-experimental-features 'nix-command flakes' build "$CONFIG_FLAKE_REF"

sudo rm -f /etc/nix/nix.conf
sudo rm -f /etc/zshrc
sudo rm -f /etc/bashrc

# This is essentially what `darwin-rebuild switch` does.
profile=/nix/var/nix/profiles/system
systemConfig="$(readlink -f ./result)"
nix-env -p "$profile" --set "$systemConfig"
"$systemConfig/activate-user"
"$systemConfig/activate"

echo "Done!"
