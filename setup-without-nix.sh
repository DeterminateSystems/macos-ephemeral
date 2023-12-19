#!/bin/sh

set -eux
set -o pipefail

(
  date
  
  ls /Volumes || true
  ls /Volumes/CONFIG || true
   
  echo "%admin ALL = NOPASSWD: ALL" > /etc/sudoers.d/passwordless
  
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

  if [ ! -f /Volumes/CONFIG/buildkite-agent/sshkey ]; then
    mkdir -p "$(dirname /Volumes/CONFIG/buildkite-agent/sshkey)" || true
    echo "Waiting a second in case the config volume shows up"
    sleep 5
  fi

  if [ ! -f /Volumes/CONFIG/buildkite-agent/sshkey ]; then
    mkdir -p "$(dirname /Volumes/CONFIG/buildkite-agent/sshkey)" || true
    ssh-keygen -t ed25519 -f /Volumes/CONFIG/buildkite-agent/sshkey -N ""
  fi

  # install xcode (for git) ugh
  # inspired by https://gist.github.com/mokagio/b974620ee8dcf5c0671f
  # and yes, this file is required, or else the command line tools don't show up in softwareupdate -l
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  softwareupdate -i "$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')"
  if ! git --help &>/dev/null; then
    # Didn't find command line tools first time, try again?
    softwareupdate -i "$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')"
  fi

  if ! pgrep -qf "tailscaled"; then
    # tailscale
    curl -L -o tailscale "https://hydra.nixos.org/job/nixpkgs/$jobset/tailscale.$arch/latest/download/1/out/bin/tailscale"
    curl -L -o tailscaled "https://hydra.nixos.org/job/nixpkgs/$jobset/tailscale.$arch/latest/download/1/out/bin/tailscaled"
    chmod +x ./tailscale{,d}

    mkdir -p /usr/local/bin/
    mv ./tailscaled /usr/local/bin/tailscaled
    mv ./tailscale /usr/local/bin/tailscale
    
    cat <<EOF > /Library/LaunchDaemons/com.tailscale.tailscaled.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>com.tailscale.tailscaled</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/tailscaled</string>
    <string>-state</string>
    <string>mem:</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

<key>StandardErrorPath</key>
<string>/var/log/tailscaled.log</string>
<key>StandardOutPath</key>
<string>/var/log/tailscaled.log</string>

</dict>
</plist>
EOF

    launchctl load /Library/LaunchDaemons/com.tailscale.tailscaled.plist
    launchctl start /Library/LaunchDaemons/com.tailscale.tailscaled.plist || true

    cat <<EOF > /Library/LaunchDaemons/com.tailscale.tailscale-auth.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>com.tailscale.tailscale-auth</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-xc</string>
    <string>sleep 5 ; /usr/local/bin/tailscale up --accept-routes --auth-key file:/var/root/tailscale.token && (while true; do sleep 2073600; done)</string>
  </array>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>

<key>StandardErrorPath</key>
<string>/var/log/tailscale-auth.log</string>
<key>StandardOutPath</key>
<string>/var/log/tailscale-auth.log</string>

</dict>
</plist>
EOF

    launchctl load /Library/LaunchDaemons/com.tailscale.tailscale-auth.plist
    launchctl start /Library/LaunchDaemons/com.tailscale.tailscale-auth.plist || true
  fi

  if ! pgrep -qf "buildkite-agent"; then
    # buildkite-agent
    curl -sL https://raw.githubusercontent.com/buildkite/agent/main/install.sh -o install-buildkite.sh
    HOME=/tmp/buildkite-agent-staging bash ./install-buildkite.sh

    mv /tmp/buildkite-agent-staging/.buildkite-agent /var/lib/buildkite-agent

    cat <<EOF > /var/lib/buildkite-agent/buildkite-agent.cfg
token="$(cat /Volumes/CONFIG/buildkite.token)"
name="%hostname-%n"
spawn=1
disconnect-after-job=true
meta-data="queue=bootstrap,mac=1,nix=0,system=$arch"
build-path="/var/lib/buildkite-agent/builds"
hooks-path="/var/lib/buildkite-agent/hooks"
tags-from-host=true
EOF

    cp /Volumes/CONFIG/buildkite-agent/sshkey ~ephemeraladmin/.ssh/id_ed25519
    cp /Volumes/CONFIG/buildkite-agent/sshkey.pub ~ephemeraladmin/.ssh/id_ed25519.pub
    chmod 600 ~ephemeraladmin/.ssh/id_ed25519
    chown ephemeraladmin:staff \
      ~ephemeraladmin/.ssh/id_ed25519 \
      ~ephemeraladmin/.ssh/id_ed25519.pub

    mkdir -p /var/lib/buildkite-agent/hooks
    cat <<'EOF' > /var/lib/buildkite-agent/hooks/agent-shutdown
#!/bin/sh

while sleep 1; do
  for machine in bonk{,-{1,2,3,4,5}}; do
    curl -X POST --connect-timeout 1 -v "http://$machine/erase-self"
    sleep 1
  done
done
EOF
    chmod +x /var/lib/buildkite-agent/hooks/agent-shutdown

    cat <<'EOF' > /var/lib/buildkite-agent/hooks/environment
#!/bin/sh
if [[ $BUILDKITE_BRANCH =~ pull/* ]]; then
  export BUILDKITE_REFSPEC="+$BUILDKITE_BRANCH:refs/remotes/origin/$BUILDKITE_BRANCH"
fi
EOF
    chmod +x /var/lib/buildkite-agent/hooks/environment

    chown -R ephemeraladmin:staff /var/lib/buildkite-agent

    touch /var/log/buildkite-agent.log
    chown ephemeraladmin:staff /var/log/buildkite-agent.log

    cat <<EOF > /Library/LaunchDaemons/com.buildkite.buildkite-agent.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.buildkite.buildkite-agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/var/lib/buildkite-agent/bin/buildkite-agent</string>
    <string>start</string>
    <string>--config</string>
    <string>/var/lib/buildkite-agent/buildkite-agent.cfg</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>/var/log/buildkite-agent.log</string>
  <key>StandardOutPath</key>
  <string>/var/log/buildkite-agent.log</string>
  <key>UserName</key>
  <string>ephemeraladmin</string>
</dict>
</plist>
EOF

    launchctl load /Library/LaunchDaemons/com.buildkite.buildkite-agent.plist
    launchctl start /Library/LaunchDaemons/com.buildkite.buildkite-agent.plist || true
  fi
) 2>&1 | tee -a /var/log/mosyle-bootstrap-script.log
