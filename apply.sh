#!/bin/sh

set -eux

BUILDKITE_TOKEN="$1"
TAILSCALE_TOKEN="$1"

cd /tmp

while ! ping -c1 hydra.nixos.org; do
	sleep 1
done

export HOME=/root

if [ ! -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	curl -L -o install.xz https://hydra.nixos.org/job/nix/master/binaryTarball.aarch64-darwin/latest/download/1
	tar -xf install.xz
	cd nix-*

	sh ./install --daemon 2>&1 | tail -n50
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
	nix-shell -p git --run "git clone https://gist.github.com/8694fac95ff865a468c94d605c4b0a66.git darwin-config"
fi

cd /nix/home/darwin-config
nix-shell -p git --run "git fetch origin && git checkout origin/HEAD"

touch /nix/home/buildkite.token
chown 0:0 /nix/home/buildkite.token
chmod 0600 /nix/home/buildkite.token
echo "$BUILDKITE_TOKEN" > /nix/home/buildkite.token

touch /nix/home/tailscale.token
chown 0:0 /nix/home/tailscale.token
chmod 0600 /nix/home/tailscale.token
echo "$TAILSCALE_TOKEN" > /nix/home/tailscale.token

if [ ! -e /etc/static/bashrc ]; then
	yes | $(nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer --no-out-link)/bin/darwin-installer  2>&1 | tail -n20
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
