#!/bin/sh

set -eu

CONFIG_REPO=$1
CONFIG_BRANCH=$2
CONFIG_TARGET=$3

#set -x

cd /tmp

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

export NIX_PATH=nixpkgs=channel:nixpkgs-unstable

if [ ! -d /nix/home ]; then
    mkdir -p /nix/home
fi

export HOME=/nix/home

nix-shell -p git 2>&1 | tail -n5
if [ ! -d /nix/home/darwin-config ]; then
    cd /nix/home
    nix-shell -p git --run "git clone $CONFIG_REPO ./darwin-config"
fi

cd /nix/home/darwin-config
nix-shell -p git --run "git fetch $CONFIG_REPO $CONFIG_BRANCH && git checkout FETCH_HEAD"

nix --extra-experimental-features 'nix-command flakes' profile install nixpkgs#git

config="/nix/home/darwin-config"
nixpkgs=$(nix --extra-experimental-features 'nix-command flakes' eval --raw "$config"#inputs.nixpkgs)
darwin=$(nix --extra-experimental-features 'nix-command flakes' eval --raw "$config"#inputs.darwin)
export NIX_PATH=darwin-config="$config/$CONFIG_TARGET":nixpkgs=$nixpkgs:darwin=$darwin

if [ ! -e /etc/static/bashrc ]; then
    nix --extra-experimental-features 'nix-command flakes' build "$config"#darwinConfigurations."$(uname -m)".system --out-link "$config/result"
    "$config/result/sw/bin/darwin-rebuild" switch --flake "$config"#"$(uname -m)"
fi

nix --extra-experimental-features 'nix-command flakes' profile remove 0

if ! hash darwin-rebuild; then
    set +eux
    . /etc/static/bashrc
    set -eux
fi

sudo rm /etc/nix/nix.conf || true

export NIX_PATH=darwin-config="$config/$CONFIG_TARGET":nixpkgs=$nixpkgs:darwin=$darwin
darwin-rebuild switch --flake "$config"#"$(uname -m)"

echo "Done!"
