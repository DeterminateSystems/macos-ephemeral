#!/bin/sh

set -eux

cd "$(mktemp -d)"

curl -L -o apply.sh https://gist.githubusercontent.com/grahamc/8694fac95ff865a468c94d605c4b0a66/raw/apply.sh
chmod +x ./apply.sh
./apply.sh "my-buildkite-token"

