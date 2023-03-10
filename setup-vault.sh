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

  if ! test -f /etc/ssh/ssh_host_rsa_key.pub; then
    echo "loading ssh because host pubkey does not exist"
    launchctl load -w /System/Library/LaunchDaemons/ssh.plist

    max=200
    while ! test -f /etc/ssh/ssh_host_rsa_key.pub; do
      echo "waiting for /etc/ssh/ssh_host_rsa_key.pub to show up... trying $max more times"
      [[ $((--max)) -gt 0 ]] || break
      sleep 3
    done
  fi

  # Don't accidentally leak any vault secrets
  set +x

  # We unconditionally do this vault thing, _IF_ the secret_id file exists and is readable
  if test -r /Volumes/CONFIG/secret_id; then
    export VAULT_ADDR=https://vault.detsys.dev:8200
    export ROLE_ID_FILE="/Volumes/CONFIG/role_id"
    export SECRET_ID_FILE="/Volumes/CONFIG/secret_id"

    export AUTH_PATH
    export SIGN_PATH
    export ROLE

    # Yes, this is ugly, but it's necessary; there's no other easy way to
    # distinguish between the foundation and detsys macs.
    if grep -q foundation "$ROLE_ID_FILE"; then
      AUTH_PATH=auth/internalservices/macos_foundation/approle/login
      SIGN_PATH=internalservices/macos_foundation/ssh_host_keys/sign/host
      ROLE=internalservices_macos_foundation_ssh_host_key_signer
    else
      AUTH_PATH=auth/internalservices/macos/approle/login
      SIGN_PATH=internalservices/macos/ssh_host_keys/sign/host
      ROLE=internalservices_macos_ssh_host_key_signer
    fi

    export VAULT_TOKEN="$($VAULT write -field=token "$AUTH_PATH" role_id=@"$ROLE_ID_FILE" secret_id=@"$SECRET_ID_FILE")"
    unset AUTH_PATH
    unset SECRET_ID_FILE
    unset ROLE_ID
    (set -x
     umask 077
     if ! grep -q foundation "$ROLE_ID_FILE" ; then
       $VAULT read -field=key internalservices/macos/tailscale/key tags=tag:ephemeral-mac-ci ephemeral=true > /var/root/tailscale.token
     fi
    )

    export VAULT_TOKEN="$($VAULT token create -field=token -role="$ROLE")"
    unset ROLE
    $VAULT write -field=signed_key "$SIGN_PATH" cert_type=host public_key=@/etc/ssh/ssh_host_rsa_key.pub > /etc/ssh/ssh_host_rsa_key.signed.pub
    unset VAULT_TOKEN
    unset SIGN_PATH
    echo "HostCertificate /etc/ssh/ssh_host_rsa_key.signed.pub" > /etc/ssh/sshd_config.d/001-ca-cert.conf
    launchctl stop com.openssh.sshd
    launchctl start com.openssh.sshd
    ssh-keyscan -c localhost
  else
    echo "Device does not have a secret_id! Exiting."
    exit 1
  fi

  set -x
) 2>&1 | tee -a /var/log/mosyle-vault-script.log
