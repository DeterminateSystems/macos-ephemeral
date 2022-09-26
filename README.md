# Ephemeral macOS for Buildkite

Set up macOS machines to automatically erase and provision themselves on a Tailscale network with Buildkite.
An erase/reinstall cycle can complete in less than 10 minutes, making it suitable for regular automation.

This README and tooling is public documentation for Determinate Systems, Inc.'s internal use.
The goal of making it public is to share the information, and foster the use of ephemeral macOS machines running Nix.

Internally, we use this tooling to support the testing of our software on macOS, and the Nix installer itself.

This repository makes many assumptions about your workflow and how you want to use this code.
These assumptions are a byproduct of the repository only being used internally, and are likely not difficult to remove.
If you use this code and documentation for yourself, consider sending contributions upstream that make it easier for people to use.

## Requirements

* We assume you are using recent Macs with either a T2 chip or Apple Silicon.
* You're using Mosyle MDM.
  Other MDMs might work, but we're focused on Mosyle.
  Feel free to send pull requests supporting other MDMs.
* Your Macs are already part of your Apple Business Manager account.
  Once you have an Apple Business Manager account, they can provide documentation on adding existing Macs.

### Hardware Requirements

* Your Macs need a mouse **directly** plugged in.
  The TinyPilot KVM doesn't count.
  A mouse plugged in to a USB hub doesn't count.
  We used the cheapest Targus mouse with a wireless dongle, and threw away the mouse.
* A USB storage device formatted and named "CONFIG".
  SSH keys and other persistent state is stored here.
* Your Macs need either a fake or real display attached.
  Amazon sells "dummy" HDMI plugs, but we used TinyPilot KVMs.


## Erasing a Mac

Select the device in `Management`,
then `Devices Overview`,
then select the `More` menu.
Click `Erase device`.
Change `Obliteration Behavior` to `Do not Obliterate`.
This requires a T2 or Apple Silicon chip.
See "ObliterationBehavior" on https://developer.apple.com/documentation/devicemanagement/erasedevicecommand/command/.

# Setting up Mosyle

## Automatic Enrollment

After erasing, the machine should fully boot and configure itself without any human interaction.
The main tasks here are to configure the region, language, and the initial user account.

### Steps

On the `Organization` tab,
select `Apple Basic Setup`,
select `Enrollment`,
click `Automated Device Enrollment`
to get to the `Device Enrollment (DEP)` page.
Click your default profile.

1. Tick `If enabled, macOS will automatically advance through all Setup Assistant screens. Available for macOS 11+ when connected to Ethernet.`
1. Select your language and region
1. Untick `Prompt user to create an account`
1. Move on to `Create additional local admin during Setup Assistant`
1. Enter a full name and use `ephemeraladmin` for the username. Note that other pieces of this system depends on the user being named `ephemeraladmin`.
1. Change the `Password` dropdown to automatically generate a password for each device
1. Tick `Set this account to be managed.`
1. Set `Rename devices after enrollment` to `mac-ephemeral-%SerialNumber%`

Click `Save`.

## Device Groups

The described automation is applied to specific machines through `Device Groups`.

### Steps

On the `Management` tab,
on the left side under `Devices`,
select `Device Groups`,
click `Add Device Group`.

1. Name it `Ephemeral CI`
1. Add your macs to the group

Click `Save`.

## Management Profile: Software Update

In general, software updates should be applied quickly and without any user interaction.
I want to be able to forget this machine exists after setup, so we have fully automated the update process.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Software Update`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Automatic Updates`
1. All of the defaults are fine as is

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.

## Management Profile: Energy Saver

If the machine sleeps it is generally not easy to wake it back up.
On my Mac Studio, waking it back up requires physically pressing the `Power` button on the back.
I tried using a wireless mouse and a KVM, but neither were able to replace it.

This profile disables sleeping.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Energy Saver`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Don't sleep`
1. Select the `Desktop` profile tab
1. Set `Put the display(s) to sleep after:` to `2 minutes`
1. Set `Put the computer to sleep after:` to `Never`
1. Set `Put the hard disk(s) to sleep after` to `Do not configure this option`
1. Under `Wake options`, tick `Wake for Ethernet network administrator access`
1. Under `Other options`, tick `Start up automatically after a power failure`


Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.

## Management Profile: Security & Privacy: Granting Mosyle access to Removable Volumes

Our provisioning script uses SSH keys stored on an external volume to survive wipes.
Apple widely prohibits programs from reading removable storage.
This means Mosyle MDM agent cannot access removable media out of the box.

This profile allows Mosyle to access removable storage.

Note that we don't actually _enable_ anything in this profile except a single checkbox for the Self-Service app.
That is intentional: that tickbox is all we need.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Security & Privacy`,
near the top of the screen select the `Privacy` tab
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Allow Mosyle access to Removable Volumes`
1. Tick `Install the Privacy Preferences Policy Control settings for the Mosyle Self-Service app to allow access to all necessary files and application data.`

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.

## Management Profile: Custom Commands: Autologin as CI

Autologin is necessary to allow fast erases and reprovisions.

Modern macOS software and hardware has two erase modes: "Erase All Content and Settings" (EACS) and "Obliterate".
EACS takes approximately 5 minutes and involves a brief reboot after clearing the existing content and settings.
Obliterate completely erases the disk and then rewrites the operating system, annd can take up to several hours.
Obliterate is the only option on older hardware.

EACS is the preferred method of implementing an ephemeral macOS machine because of the fast cycle time.
In order for EACS to work, the machine must have a "Bootstrap Token" escrowed with our MDM server.
The only way to escrow a bootstrap token is to have an administrative user log in.

This profile creates an administrative user with a random, unknown password, and causes it to automatically log in.
After creating the user, the machine is rebooted to cause the login to happen.
### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Custom Commands`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Autologin as CI`
1. Select the `Code` profile tab
1. Click the code text box
1. Paste the contents of `auto-login.sh` into the box
1. Click the checkmark in the top right of the Code Edit window
1. Select the `Execution Settings` profile tab
1. For `Execute Command` select `Only based on schedule or events`
1. For `Event` tick `Upon Enrollment Only`

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.

## Management Profile: Custom Commands: Setup SSH

Configure SSH keys and start the SSH daemon for the DEP-managed administrative user, `ephemeraladmin`.

This script runs very frequently to ensure SSH is both running, and your users' keys are on the machine.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Custom Commands`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Setup SSH`
1. Select the `Code` profile tab
1. Click the code text box
1. Paste the contents of `setup-ssh.sh` into the box
1. Edit the list of GitHub user names near line 9 to match your own users
1. Click the checkmark in the top right of the Code Edit window
1. Select the `Execution Settings` profile tab
1. For `Execute Command` select `Only based on schedule or events`
1. For `Event` untick `Upon Enrollment Only`
1. For `Event` tick `Every start up of the Mac`, `Every user sign-in`, and `Every "Device Info Update"`.

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.


## Management Profile: Custom Commands: Install Nix

Installs Nix and nix-darwin, which is configured to run a Buildkite agent and join our Tailscale network.]

Note that right now this code assumes you're installing everything for DetSys purposes.
It is an explicit goal for this repository to support configuring things for *your* purposes without necessarily having to fork the repo.
Please open issues discussing or send PRs improving this.

#### Tailscale Token

The tailscale token should be configured as follows.

First configure a tag to assign to ephemeral macs, by adding this to your ACL:

```json
	"tagOwners": {
		"tag:ephemeral-mac-ci": ["you@example.com"],
	}
```

1. Visit https://login.tailscale.com/admin/settings/keys
1. Click `Generate Auth Key`
1. Enable `Reusable`
1. Enable `Ephemeral`
1. Enable `Tags`, and assign the `ephemeral-mac-ci` tag.

Save the generated token into `/Volumes/CONFIG/tailscale.token`.

#### Buildkite Token

Save the buildkite agent token into `/Volumes/CONFIG/buildkite.token`.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Custom Commands`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Install Nix`
1. Select the `Code` profile tab
1. Click the code text box
1. Paste the contents of `install-nix-fetcher.sh` into the box
1. Click the checkmark in the top right of the Code Edit window
1. Select the `Execution Settings` profile tab
1. For `Execute Command` select `Only based on schedule or events`
1. For `Event` untick `Upon Enrollment Only`
1. For `Event` tick `Every user sign-in`

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.



## Management Profile: Custom Commands: Show Public SSH Key

Shows the public key of the private key generated on the box.

### Steps

On the `Management` tab,
on the left side under `Management Profiles`,
select `Custom Commands`,
click `Add new profile`.

If the profile type isn't there,
click `Activate New Profile Type`,
search for it by name,
click `Activate`,
then click `Add new profile`.

1. Name the profile `Show Public SSH Key`
1. Select the `Code` profile tab
1. Click the code text box
1. Paste `cat /Volumes/CONFIG/buildkite-agent/sshkey.pub` into the box
1. Click the checkmark in the top right of the Code Edit window
1. Select the `Execution Settings` profile tab
1. For `Execute Command` select `Only based on schedule or events`
1. For `Event` untick `Upon Enrollment Only`
1. For `Event` tick `Every start up of the Mac`
1. For `Event` tick `Every user sign-in`
1. For `Event` tick `Every "Device info" update"`

Under `Profile Assignment`,
click `+ Add Assignment`,
select `Devices from specific Devices Group`,
tick `Ephemeral CI`.

Click `Save`.
