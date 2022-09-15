#!/bin/sh

set -eu

BUILDKITE_TOKEN="$1"
TAILSCALE_TOKEN="$2"

#set -x

cd /tmp

while ! ping -c1 nixos.org; do
    sleep 1
done

export HOME=/root

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

export NIX_PATH=darwin-config=/nix/home/darwin-config/configuration.nix:nixpkgs=channel:nixpkgs-unstable:darwin=https://github.com/LnL7/nix-darwin/archive/master.tar.gz


if [ ! -d /nix/home ]; then
    mkdir -p /nix/home
fi

export HOME=/nix/home

nix-shell -p git 2>&1 | tail -n5
if [ ! -d /nix/home/darwin-config ]; then
    cd /nix/home
    nix-shell -p git --run "git clone https://github.com/DeterminateSystems/macos-ephemeral.git darwin-config"
fi

cd /nix/home/darwin-config
nix-shell -p git --run "git fetch origin && git checkout origin/HEAD"

touch /nix/home/buildkite.token
chown 0:0 /nix/home/buildkite.token
chmod 0600 /nix/home/buildkite.token
set +x
echo "$BUILDKITE_TOKEN" > /nix/home/buildkite.token
set -x

touch /nix/home/tailscale.token
chown 0:0 /nix/home/tailscale.token
chmod 0600 /nix/home/tailscale.token
set +x
echo "$TAILSCALE_TOKEN" > /nix/home/tailscale.token
set -x

if [ ! -e /etc/static/bashrc ]; then
yes |    $(nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer --no-out-link)/bin/darwin-installer 2>&1 | tail -n10
fi

if ! hash darwin-rebuild; then
    set +eux
    . /etc/static/bashrc
    set -eux
fi

export NIX_PATH=darwin-config=/nix/home/darwin-config/configuration.nix:nixpkgs=channel:nixpkgs-unstable:darwin=https://github.com/LnL7/nix-darwin/archive/master.tar.gz

sudo rm /etc/nix/nix.conf || true

darwin-rebuild switch

echo "Done!"
