#!/bin/sh

set -eux

while ! ping -c1 github.com; do
	sleep 1
done

cd "$(mktemp -d)"

curl -L -o apply.sh https://github.com/DeterminateSystems/macos-ephemeral/raw/main/apply.sh
chmod +x ./apply.sh

repo="https://github.com/DeterminateSystems/macos-ephemeral.git"
branch="HEAD"
cfgpath="configuration.nix"

./apply.sh "$repo" "$branch" "$cfgpath"
