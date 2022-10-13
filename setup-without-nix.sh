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
  
  
  if ! pgrep -qf "tailscaled"; then
    cd ~root

    if [ "$(uname -m)" = "arm64" ]; then
      jobset=nixpkgs-unstable-aarch64-darwin
      arch=aarch64-darwin
    else
      jobset=trunk
      arch=x86_64-darwin
    fi

    curl -L -o tailscale "https://hydra.nixos.org/job/nixpkgs/$jobset/tailscale.$arch/latest/download/1/out/bin/tailscale"
    curl -L -o tailscaled "https://hydra.nixos.org/job/nixpkgs/$jobset/tailscale.$arch/latest/download/1/out/bin/tailscaled"
    chmod +x ./tailscale{,d}

    mkdir -p /usr/local/bin/
    mv ./tailscaled /usr/local/bin/tailscaled
    
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
    
    sleep 5
    ./tailscale up --auth-key file:/Volumes/CONFIG/tailscale.token
  fi
) 2>&1 | tee -a /var/log/mosyle-bootstrap-script.log
