#!/bin/sh

set -eux

cd "$(mktemp -d)"

while ! ping -c1 gist.githubusercontent.com; do
	sleep 1
done

curl -L -o apply.sh https://gist.githubusercontent.com/grahamc/8694fac95ff865a468c94d605c4b0a66/raw/apply.sh
chmod +x ./apply.sh
./apply.sh "my-buildkite-token" "my-tailscale-token"

