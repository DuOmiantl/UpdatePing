# UpdatePing

> Checks quietly. Pings you when updates are available.

English | [简体中文](./README.zh-CN.md)

A lightweight Windows app update reminder.

UpdatePing checks your installed apps after you sign in to Windows. If no updates are available, it exits quietly.

If updates are available, it sends you a Windows notification. You can then open UpdatePing, review the available versions, and choose exactly which apps you want to update.

**No always-on background service. No silent updates. No ads.**

Powered by `winget`, with Scoop support.

## How it works

```text
Sign in to Windows
        ↓
UpdatePing checks for app updates
        ↓
No updates → Exit quietly

Updates found
        ↓
Windows notification
        ↓
Open UpdatePing
        ↓
Review current / available versions
        ↓
Select apps → Confirm → Update selected apps
```

Checking is automatic. Updating application packages is your decision.

## Features

- Checks once at sign-in, after a one-minute delay.
- Shows available apps, installed versions, available versions, package IDs, and sources in a graphical window.
- Offers Select All, Clear, and Check Again controls; updates only selected apps after confirmation.
- Sends a Windows notification only when updates are found.
- Writes a readable report after each successful check, accessible from the window.
- Runs selected updates in a separate window so you can follow the package manager's prompts.

## What it does NOT do

- No always-on background service.
- No automatic upgrade-all behavior.
- No silent software updates.
- No ads or bundled software.
- No software recommendations.
- No proprietary app store or replacement package ecosystem.

You decide what gets updated.

## Why UpdatePing?

“Ping” can mean sending a small signal or giving someone a quick notification. That is exactly what UpdatePing does: it checks quietly and only pings you when an update needs your attention.

## Installation

**No traditional installer required.** There is still a one-time setup step to enable automatic checks.

Download or clone this project. Open Windows PowerShell in the project directory and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

The setup script describes its actions, then:

- Creates `%USERPROFILE%\SoftwareUpdateManager\` and copies `SoftwareUpdateManager.ps1` there.
- Creates the desktop launcher `%USERPROFILE%\Desktop\UpdatePing.cmd`.
- Writes `install.json` to record the project, version, and installed script hash.
- Registers the current-user task `SoftwareUpdateManager-v0.1.0`, which checks at sign-in after a one-minute delay in an interactive session with limited privileges.

Setup does not update application packages. Repeating setup with matching files and a matching task does not create a duplicate task. Different existing files or tasks cause setup to stop rather than overwrite them. Other scripts and shortcuts are left alone.

The internal installation directory, script filename, and task name retain their original names for compatibility; the product is UpdatePing, version v0.1.0.

### Replacing an existing installation

Setup does not overwrite a different installed script. Back up any reports or other files you want to keep, then run `Uninstall.ps1` before setting up the new copy. The uninstaller also recognizes the old `Software Update Manager.cmd` launcher when its contents match this project.

If you keep the report during uninstall, the installation folder remains. Move retained files somewhere safe and remove the empty folder before reinstalling: setup deliberately rejects an existing folder without an installation record. Do not simply replace the installed script, because that leaves its recorded hash out of sync.

## Usage

Double-click **UpdatePing.cmd** on the desktop. The interface currently uses Chinese labels:

1. Review the current and available versions.
2. Check the apps you want and click **更新所选** (Update Selected).
3. Confirm your selection. Updates run in a separate PowerShell window; the package managers may request confirmation or elevation.
4. Return to UpdatePing and click **重新检查** (Check Again) to verify the result.

Use **打开报告** (Open Report) to view the latest report. You can also run without setting up the sign-in task:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\SoftwareUpdateManager.ps1
```

To run the installed background check manually:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "$env:USERPROFILE\SoftwareUpdateManager\SoftwareUpdateManager.ps1" -CheckOnly
```

## What are winget and Scoop?

`winget` is Microsoft's Windows package manager. Scoop is a popular open-source package manager for Windows.

UpdatePing uses them as update engines and provides a simpler graphical workflow on top. Users do not need to memorize package-manager commands for normal use. It checks the engines available on your system; it does not install them for you or guarantee coverage of every installed app.

## Requirements

- Windows with Windows PowerShell 5.1; modern Toast notifications are intended for Windows 10 and 11.
- `winget` and/or Scoop available to the current user.
- An interactive signed-in session and Windows notification settings that permit notifications for visible reminders.

No Windows Terminal, BurntToast, Node.js, Python, or additional PowerShell modules are required.

## Technical details

- `SoftwareUpdateManager.ps1` contains the GUI, checks, reports, notifications, and selected updates. `Install.ps1` and `Uninstall.ps1` handle current-user setup and removal.
- `-CheckOnly` checks and writes `software-updates-latest.txt` in the script directory, then exits. It does not open the GUI or update application packages.
- The Scoop check runs `scoop update` without a package name to refresh Scoop and bucket metadata, then `scoop status`. The winget check queries its available-upgrade list. The program does not run `winget upgrade --all` or `scoop update *`.
- Modern Toast is the primary notification method. On notification, the script registers the display name **UpdatePing** under `HKCU\Software\Classes\AppUserModelId\SoftwareUpdateManager`. The internal identity and notification group remain unchanged to preserve existing settings and replace repeated notifications.
- If Toast registration, sending, or notification settings fail, UpdatePing attempts a legacy tray balloon. Errors from either notification method do not fail the check or discard its report. The fallback remains alive for up to 20 seconds, then releases its tray icon.
- Toast does not launch UpdatePing or the report when clicked. Open UpdatePing from its desktop launcher; the legacy balloon can open the report while its process remains alive.
- Notifications can be suppressed by Windows settings or Do Not Disturb. Sending a notification does not guarantee a visible banner.
- winget's human-readable table can change with language, column width, or version; some rows may not be recognized. A detected update comes from the package source and may differ from the latest release in the app's built-in stable channel. Check failures are reported; package-manager failures occur before the report is rewritten.
- The GUI can pause while checking. Redirected desktops and all language/package-manager combinations have not been fully verified; setup uses `%USERPROFILE%\Desktop`.
- Runtime reports, `*.bak` files, and generated update scripts are ignored by Git.

## Uninstall

From the project directory, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

The script verifies the installation record, script hash, launcher contents, and task configuration before removing this project's task, launcher, installed script, and installation record. Modified files or tasks cause it to stop for manual review. It recognizes both `UpdatePing.cmd` and the old launcher name, but removes only matching launchers.

If a report exists, it asks whether to delete it; keeping it is the default. The notification registration is removed only if it contains just this project's current or former display name, with no other values or subkeys. The installation folder is removed only when empty. winget, Scoop, and other user files are not removed.

## License

MIT. See [LICENSE](./LICENSE).
