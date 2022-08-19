# Ephemeral macOS for Buildkite

## Automatic Enrollment

After erasing, the machine should fully boot and configure itself without any human interaction.
The main tasks here are to configure the region, language, and the initial user account.

### Steps

On the "Organization" tab,
select "Apple Basic Setup",
select "Enrollment",
click "Automated Device Enrollment"
to get to the "Device Enrollment (DEP)" page.
Click your default profile.

1. Tick "If enabled, macOS will automatically advance through all Setup Assistant screens. Available for macOS 11+ when connected to Ethernet."
1. Select your language and region
1. Untick "Prompt user to create an account"
1. Move on to "Create additional local admin during Setup Assistant"
1. Enter a full name and username
1. Change the "Password" dropdown to automatically generate a password for each device
1. Tick "Set this account to be managed."
1. Set "Rename devices after enrollment" to "mac-ephemeral-%SerialNumber%"

Click "Save".

## Device Groups

The described automation is applied to specific machines through "Device Groups".

### Steps

On the "Management" tab,
on the left side under "Devices",
select "Device Groups",
click "Add Device Group".

1. Name it "Ephemeral CI"
2. Add your macs to the group

Click "Save".

## Management Profile: Software Update

In general, software updates should be applied quickly and without any user interaction.
I want to be able to forget this machine exists after setup, so we have fully automated the update process.

### Steps

On the "Management" tab,
on the left side under "Management Profiles",
select "Software Update",
click "Add new profile".

If the profile type isn't there,
click "Activate New Profile Type",
search for it by name,
click "Activate",
then click "Add new profile".

1. Name the profile "Automatic Updates"
2. All of the defaults are fine as is

Under "Profile Assignment",
click "+ Add Assignment",
select "Devices from specific Devices Group",
tick "Ephemeral CI".

Click "Save".

## Management Profile: Energy Saver

If the machine sleeps it is generally not easy to wake it back up.
On my Mac Studio, waking it back up requires physically pressing the "Power" button on the back.
I tried using a wireless mouse and a KVM, but neither were able to replace it.

This profile disbales sleeping.

### Steps

On the "Management" tab,
on the left side under "Management Profiles",
select "Energy Saver",
click "Add new profile".

If the profile type isn't there,
click "Activate New Profile Type",
search for it by name,
click "Activate",
then click "Add new profile".

1. Name the profile "Don't sleep"
2. Select the "Desktop" profile tab
3. Set "Put the display(s) to sleep after:" to "2 minutes"
4. Set "Put the computer to sleep after:" to "Never"
5. Set "Put the hard disk(s) to sleep after" to "Do not configure this option"
6. Under "Wake options", tick "Wake for Ethernet network administrator access"
7. Under "Other options", tick "Start up automatically after a power failure"


Under "Profile Assignment",
click "+ Add Assignment",
select "Devices from specific Devices Group",
tick "Ephemeral CI".

Click "Save".

## Management Profile: Energy Saver

If the machine sleeps it is generally not easy to wake it back up.
On my Mac Studio, waking it back up requires physically pressing the "Power" button on the back.
I tried using a wireless mouse and a KVM, but neither were able to replace it.

This profile disbales sleeping.

### Steps

On the "Management" tab,
on the left side under "Management Profiles",
select "Energy Saver",
click "Add new profile".

If the profile type isn't there,
click "Activate New Profile Type",
search for it by name,
click "Activate",
then click "Add new profile".

1. Name the profile "Don't sleep"
2. Select the "Desktop" profile tab
3. Set "Put the display(s) to sleep after:" to "2 minutes"
4. Set "Put the computer to sleep after:" to "Never"
5. Set "Put the hard disk(s) to sleep after" to "Do not configure this option"
6. Under "Wake options", tick "Wake for Ethernet network administrator access"
7. Under "Other options", tick "Start upu automatically after a power failure"


Under "Profile Assignment",
click "+ Add Assignment",
select "Devices from specific Devices Group",
tick "Ephemeral CI".

Click "Save".
