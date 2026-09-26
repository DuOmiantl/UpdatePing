# UpdatePing

> 安静检查，有更新才 Ping 你。

[English](./README.md) | 简体中文

一个轻量的 Windows 软件更新提醒工具。

登录 Windows 后，UpdatePing 会自动检查已安装软件是否存在更新。没有更新时，它会安静退出。

发现更新时，它会发送一条 Windows 通知。你可以随后打开 UpdatePing，查看当前版本和可用版本，并自行选择需要更新的软件。

**不常驻后台，不静默更新，不带广告。**

基于 `winget`，并支持 Scoop。

## 工作方式

```text
登录 Windows
    ↓
UpdatePing 检查软件更新
    ↓
没有更新 → 安静退出

发现更新
    ↓
Windows 通知
    ↓
打开 UpdatePing
    ↓
查看当前版本 / 可用版本
    ↓
自己勾选 → 确认 → 更新所选软件
```

自动的是检查。是否更新应用软件、更新哪些软件，由你决定。

## 功能

- 每次登录后延迟 1 分钟检查一次。
- 在图形窗口中显示待更新软件、当前版本、可用版本、包 ID 和来源。
- 支持全选、清空、重新检查；只有勾选并确认后才更新所选软件。
- 仅在发现更新时发送 Windows 通知。
- 每次成功检查后生成可读报告，可从窗口打开。
- 在独立窗口执行所选更新，方便查看包管理器的提示。

## 它不会做什么

- 不常驻后台。
- 不自动执行全部更新。
- 不静默升级软件。
- 不推送广告，不捆绑其他软件。
- 不推荐用户安装其他软件。
- 不建立自己的应用商店或软件包生态。

更新哪些软件，由用户决定。

## 为什么叫 UpdatePing？

“Ping”既可以表示发送一个轻量的探测信号，也常用于表示“提醒一下 / 戳一下”。这正是 UpdatePing 的工作方式：平时安静检查，只有发现更新时才 Ping 你一下。

## 首次设置

**无需传统安装程序。** 但启用登录后自动检查仍需要完成一次设置。

下载或克隆本项目，在项目目录打开 Windows PowerShell，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

设置脚本会先说明操作，然后：

- 创建 `%USERPROFILE%\SoftwareUpdateManager\`，并将 `SoftwareUpdateManager.ps1` 复制进去。
- 创建桌面入口 `%USERPROFILE%\Desktop\UpdatePing.cmd`。
- 写入 `install.json`，记录项目标识、版本及已安装脚本的哈希。
- 注册当前用户的 `SoftwareUpdateManager-v0.1.0` 任务计划，在交互式登录会话中以普通权限运行，登录后延迟 1 分钟检查。

设置不会更新应用软件。已有文件和任务都匹配时，重复设置不会创建重复任务；发现不同内容的同名文件或任务时会停止，避免覆盖。其他脚本和快捷方式不会被修改。

为兼容现有引用，内部安装目录、脚本文件名和任务名称暂时保留原名；产品名称为 UpdatePing，版本 v0.1.0。

### 替换已有安装

设置脚本不会覆盖内容不同的已安装脚本。请先备份需要保留的报告和其他文件，运行 `Uninstall.ps1`，再设置新版本。卸载脚本也能识别旧的 `Software Update Manager.cmd` 入口，但要求其内容与本项目匹配。

如果卸载时保留报告，安装目录也会保留。重新设置前，请将保留的文件移到安全位置，再删除空目录：设置脚本会拒绝没有安装记录的已有目录。不要直接覆盖已安装脚本，否则安装记录中的哈希会失去同步。

## 使用

双击桌面上的 **UpdatePing.cmd**。界面继续使用中文：

1. 查看当前版本和可用版本。
2. 勾选需要更新的软件，点击 **更新所选**。
3. 确认选择后，在独立 PowerShell 窗口中执行更新；包管理器可能显示安装确认或权限提示。
4. 更新结束后回到 UpdatePing，点击 **重新检查** 核对结果。

点击 **打开报告** 可查看最新报告。如果暂时不设置登录检查，也可直接运行：

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\SoftwareUpdateManager.ps1
```

手动运行已安装版本的后台检查：

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "$env:USERPROFILE\SoftwareUpdateManager\SoftwareUpdateManager.ps1" -CheckOnly
```

## winget 和 Scoop 是什么？

`winget` 是微软提供的 Windows 软件包管理工具。Scoop 是一个流行的 Windows 开源软件包管理器。

UpdatePing 使用它们作为底层更新能力，并提供更直观的检查、通知和选择更新流程。日常使用不需要记住这些命令。它会检查当前系统可用的包管理器，不会替用户安装它们，也不保证能覆盖所有已安装软件。

## 环境要求

- Windows 和 Windows PowerShell 5.1；现代 Toast 通知面向 Windows 10 和 Windows 11。
- 当前用户可以使用 `winget` 和/或 Scoop。
- 要看到通知，需要交互式登录会话及允许显示通知的 Windows 设置。

无需 Windows Terminal、BurntToast、Node.js、Python 或额外 PowerShell 模块。

## 技术细节

- `SoftwareUpdateManager.ps1` 包含 GUI、检查、报告、通知和所选更新；`Install.ps1`、`Uninstall.ps1` 负责当前用户的设置与移除。
- `-CheckOnly` 检查并将 `software-updates-latest.txt` 写到脚本所在目录，然后退出，不打开 GUI，不更新应用软件。
- Scoop 检查先运行不带包名的 `scoop update`，刷新 Scoop 和 bucket 元数据，再运行 `scoop status`；winget 查询可升级列表。程序不会执行 `winget upgrade --all` 或 `scoop update *`。
- 优先使用现代 Toast。在发送通知时，脚本在 `HKCU\Software\Classes\AppUserModelId\SoftwareUpdateManager` 下注册显示名称 **UpdatePing**。内部通知标识和分组保持原样，保留已有设置并替换重复通知。
- Toast 注册、发送或通知设置检查失败时，尝试旧式托盘气泡。两种通知方式的异常都不会导致检查失败或丢弃报告。fallback 最多保活 20 秒，之后释放托盘图标。
- Toast 点击后不会启动 UpdatePing 或报告，请从桌面入口打开；旧式气泡可在进程仍运行期间点击打开报告。
- Windows 通知设置或“请勿打扰”可能抑制提醒；发送成功不代表一定出现横幅。
- winget 的人类可读表格可能随语言、列宽或版本改变，部分条目可能无法识别。可用版本来自软件源，可能与应用内置稳定通道的最新版不同。检查失败会报错；包管理器失败发生在报告被重写之前。
- GUI 检查时可能暂时无响应。重定向桌面及所有语言、包管理器版本组合尚未充分验证；设置脚本使用 `%USERPROFILE%\Desktop`。
- Git 忽略运行报告、`*.bak` 和生成的更新脚本。

## 卸载

在项目目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

脚本会先核对安装记录、脚本哈希、入口内容及任务配置，再移除本项目的任务计划、桌面入口、已安装脚本和安装记录。发现文件或任务被修改时，会停止并要求手工确认。它兼容 `UpdatePing.cmd` 和旧入口名，但只移除内容匹配的入口。

若有报告，会询问是否删除，默认保留。通知注册项只有在仅包含本项目当前或原显示名称、没有其他值或子项时才删除。安装目录仅在清空后删除。卸载不会移除 winget、Scoop 或其他用户文件。

## 许可证

MIT。详见 [LICENSE](./LICENSE)。
