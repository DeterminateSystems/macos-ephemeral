#!/bin/sh

set -eux
set -o pipefail

(
  date

  while ! ping -c1 github.com; do
    sleep 1
  done

  if [ "$(uname -m)" = "arm64" ]; then
    jobset=nixpkgs-unstable-aarch64-darwin
    arch=aarch64-darwin
  else
    jobset=trunk
    arch=x86_64-darwin
  fi

  cd ~root

  while [ ! -d /Volumes/CONFIG ]; do
    echo "Waiting for /Volumes/CONFIG to exist ..."
    sleep 1
  done

  # If vault isn't already available (i.e. via Nixpkgs), and it doesn't exist at
  # that path, then get it from Hydra
  export VAULT
  if ! hash vault; then
    if ! test -f /usr/local/bin/vault; then
      curl -L -o vault "https://hydra.nixos.org/job/nixpkgs/$jobset/vault.$arch/latest/download/1/out/bin/vault"
      chmod +x ./vault

      mkdir -p /usr/local/bin/
      mv ./vault /usr/local/bin/vault
    fi

    VAULT=/usr/local/bin/vault
  else
    VAULT="$(command -v vault)"
  fi

  # Don't accidentally leak any vault secrets
  set +x

  # We unconditionally do this vault thing, _IF_ the secret_id file exists and is readable
  if test -r /Volumes/CONFIG/secret_id; then
    export VAULT_ADDR=https://vault-ipv6.detsys.dev:8200
    export ROLE_ID_FILE="/Volumes/CONFIG/role_id"
    export SECRET_ID_FILE="/Volumes/CONFIG/secret_id"

    export AUTH_PATH

    # Yes, this is ugly, but it's necessary; there's no other easy way to
    # distinguish between the foundation and detsys macs.
    if grep -q foundation "$ROLE_ID_FILE"; then
      AUTH_PATH=auth/internalservices/macos_foundation/approle/login
    else
      AUTH_PATH=auth/internalservices/macos/approle/login
    fi

    export VAULT_TOKEN="$($VAULT write -field=token "$AUTH_PATH" role_id=@"$ROLE_ID_FILE" secret_id=@"$SECRET_ID_FILE")"
    unset AUTH_PATH
    unset SECRET_ID_FILE

    $VAULT kv put internalservices/macos/kv/"$(cat ROLE_ID_FILE)"/password password=@"$EPHEMERALADMIN_PASSWORD_FILE"
    rm "$EPHEMERALADMIN_PASSWORD_FILE"
    unset EPHEMERALADMIN_PASSWORD_FILE
    unset ROLE_ID_FILE
  else
    echo "Device does not have a secret_id! Exiting."
    exit 1
  fi

  set -x

  # We'll get vault somewhere in the setup-vault.sh script
  rm $VAULT
) 2>&1 | tee -a /var/log/mosyle-password-script.log
