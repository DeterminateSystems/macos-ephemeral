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
2. Select your language and region.
3. Untick "Prompt user to create an account".
4. Enter a full name and username.
5. Change the "Password" dropdown to automatically generate a password for each device.
6. Tick "Set this account to be managed."

Click "Save".

## Device Groups

The described automation is applied to specific machines through "Device Groups".

### Steps

On the "Management" tab,
on the left side under "Devices",
select "Device Groups",
click "Add Device Group".

1. Name it "Ephemeral CI".
2. Add your macs to the group.

Click "Save".

## Management Profiles