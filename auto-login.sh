#!/bin/sh

set -eux


while ! ping -c1 github.com; do
	sleep 1
done

cd "$(mktemp -d)"

cat <<EOF > mkuser.sh.check
10a45bd537435482cd5caef0272d6b6b95dc7089  ./mkuser.sh
EOF
curl -L https://raw.githubusercontent.com/freegeek-pdx/mkuser/2022.9.30-1/mkuser.sh > mkuser.sh
if ! shasum -c ./mkuser.sh.check; then
  echo "mkuser.sh was not what we expected."
  exit 1
fi

chmod +x ./mkuser.sh

openssl rand -base64 48 | ./mkuser.sh \
    --do-not-confirm \
    --administrator \
    --automatic-login \
    --no-picture \
    --stdin-password \
    --account-name ci \
    --full-name ci

cat <<EOF | tee /Library/LaunchDaemons/systems.determinate.ephemeral-macos.reboot.plist > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>systems.determinate.ephemeral-macos.reboot</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string>
      <string>-c</string>
      <string>sleep 5; /sbin/reboot</string>
    </array>
  </dict>
</plist>
EOF

launchctl unload /Library/LaunchDaemons/systems.determinate.ephemeral-macos.reboot.plist
launchctl load -w /Library/LaunchDaemons/systems.determinate.ephemeral-macos.reboot.plist
launchctl kickstart -kp system/systems.determinate.ephemeral-macos.reboot
