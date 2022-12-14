#!/bin/sh

set -eux
set -o pipefail

(
  date

  ls /Volumes || true
  ls /Volumes/CONFIG || true

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
  if ! vault version &>/dev/null && ! test -f /usr/local/bin/vault; then
    curl -L -o vault "https://hydra.nixos.org/job/nixpkgs/$jobset/vault.$arch/latest/download/1/out/bin/vault"
    chmod +x ./vault

    mkdir -p /usr/local/bin/
    mv ./vault /usr/local/bin/vault
  fi

  # Don't accidentally leak any vault secrets
  set +x

  # We unconditionally do this vault thing, _IF_ the secret_id file exists and is readable
  if test -r /Volumes/CONFIG/secret_id; then
    export VAULT_ADDR=https://vault.detsys.dev:8200
    export ROLE_ID="$(echo "$(hostname)" | sed 's@mac-\(.*\)\.local@\1@').macos.detsys.dev"
    export SECRET_ID_FILE="/Volumes/CONFIG/secret_id"
    export VAULT_TOKEN="$(vault write -field=token auth/internalservices/macos/approle/login role_id="$ROLE_ID" secret_id=@"$SECRET_ID_FILE")"
    unset SECRET_ID_FILE
    unset ROLE_ID
    export VAULT_TOKEN="$(vault token create -field=token -role=internalservices_macos_ssh_host_key_signer)"
    vault write -field=signed_key internalservices/macos/ssh_host_keys/sign/host cert_type=host public_key=@/etc/ssh/ssh_host_rsa_key.pub > /etc/ssh/ssh_host_rsa_key.signed.pub
    unset VAULT_TOKEN
    echo "HostCertificate /etc/ssh/ssh_host_rsa_key.signed.pub" > /etc/ssh/sshd_config.d/001-ca-cert.conf
    launchctl stop com.openssh.sshd
    launchctl start com.openssh.sshd
  else
    echo "Device does not have a secret_id! Exiting."
    exit 1
  fi

  set -x
) 2>&1 | tee -a /var/log/mosyle-vault-script.log
