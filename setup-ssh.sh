set -eux

launchctl load -w /System/Library/LaunchDaemons/ssh.plist

mkdir -p /Users/ephemeraladmin/.ssh
cd /Users/ephemeraladmin/.ssh

while ! ping -c1 github.com; do
	sleep 1
done

echo "" > keys.next
for ghuser in grahamc grahamc grahamc; do 
  curl -L https://github.com/$ghuser.keys >> keys.next
done

mv keys.next authorized_keys

chown -R ephemeraladmin /Users/ephemeraladmin/.ssh
