# Software Update Manager

English | [简体中文](README.zh-CN.md)

Software Update Manager v0.1.0 is a lightweight, transparent Windows update reminder. It lists available Winget and Scoop updates in a WinForms window so you can choose which packages to update. The source is readable PowerShell; no Node.js, Python, or additional framework is required.

## Why it exists

Windows applications may be managed by Winget or Scoop. This tool provides one place to check both while leaving installation to the original package managers. Compared with UniGetUI, it aims to be smaller and easier to inspect, rather than a full software center.

## Features

- Lists the name, installed version, available version, package ID, and source of available updates.
- Updates only checked packages after confirmation in a separate PowerShell window; includes Select All, Clear, and Check Again controls.
- Writes `software-updates-latest.txt` after a successful check and can open it from the GUI.
- Supports a `-CheckOnly` background mode that shows a Windows notification when updates are found, without installing them.
- Creates a current-user scheduled task that runs once at sign-in after a one-minute delay.

## Screenshot

![Main window](screenshots/main-window.png)

## Requirements and installation

The project has been thoroughly tested only on Windows with Windows PowerShell 5.1. Winget and/or Scoop must be available. Download or clone this project, then run from its directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

The installer first describes its actions. It copies `SoftwareUpdateManager.ps1` to `%USERPROFILE%\SoftwareUpdateManager\`, creates `%USERPROFILE%\Desktop\Software Update Manager.cmd`, and registers the `SoftwareUpdateManager-v0.1.0` task for the current user. Reports are stored in the installation directory. Installation does not update any applications. If a same-name file or task has different content, installation stops instead of overwriting it. Running the same installer again does not create a duplicate task.

The installer does not touch an older script in the `Scripts` directory or existing desktop shortcuts.

## Usage

Double-click `Software Update Manager.cmd` on the desktop. After the check finishes, select the packages you want and click the “更新所选” (Update Selected) button, then confirm. Updates run in a new PowerShell window. When they finish, click “重新检查” (Check Again) in the GUI to verify the result. The package managers may still request confirmation or elevation.

To run a background check manually:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "$env:USERPROFILE\SoftwareUpdateManager\SoftwareUpdateManager.ps1" -CheckOnly
```

The scheduled task uses the same `-CheckOnly` mode. It refreshes Scoop metadata, queries available updates, writes the report, and shows a notification if updates are found. `scoop update` without a package name refreshes Scoop and bucket metadata; the program does not run `scoop update *`.

## Uninstallation

From the downloaded or cloned project directory, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

The uninstaller removes only this project's scheduled task, desktop launcher, and installed program file. If a report exists, it explicitly asks whether to delete it; the default is to keep it. Modified installed files, launcher, or task are not blindly removed. It does not remove Winget, Scoop, or other user files.

## Safety and known limitations

- It never runs `winget upgrade --all` or `scoop update *` by default. Application updates require selection and confirmation in the GUI.
- Winget and Scoop packages and sources are maintained by their respective repositories. Review the package ID, source, and installation prompts before updating.
- Winget's human-readable table is not a stable machine interface. Language, column width, or version changes may prevent some rows from being parsed. Command failures are reported, and the last successful report is retained.
- The “available version” reported by Winget comes from its source and may differ from the latest version in a vendor's built-in stable channel.
- The GUI may be temporarily unresponsive while checking. Notifications depend on an interactive user session and Windows notification settings.
- Other languages, redirected desktops, and all combinations of Winget and Scoop versions have not been thoroughly tested. The desktop launcher uses `%USERPROFILE%\Desktop`.

## Files

- `SoftwareUpdateManager.ps1`: GUI, checks, report, notification, and selected updates.
- `Install.ps1` / `Uninstall.ps1`: current-user installation and removal.
- `screenshots/`: location for feature screenshots.

Licensed under MIT; see [`LICENSE`](LICENSE).
