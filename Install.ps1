$ErrorActionPreference = 'Stop'

$installDir = Join-Path $env:USERPROFILE 'SoftwareUpdateManager'
$sourcePath = Join-Path $PSScriptRoot 'SoftwareUpdateManager.ps1'
$programPath = Join-Path $installDir 'SoftwareUpdateManager.ps1'
$manifestPath = Join-Path $installDir 'install.json'
$desktopPath = Join-Path (Join-Path $env:USERPROFILE 'Desktop') 'Software Update Manager.cmd'
$taskName = 'SoftwareUpdateManager-v0.1.0'
$taskUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskArguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $programPath + '" -CheckOnly'
$launcher = "@echo off`r`npowershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File `"%USERPROFILE%\SoftwareUpdateManager\SoftwareUpdateManager.ps1`"`r`nif errorlevel 1 pause`r`n"

Write-Host "将安装程序到 $installDir，创建桌面入口 $desktopPath，并为当前用户创建登录后延迟 1 分钟的后台检查任务 $taskName。"
Write-Host '安装不会执行任何软件更新；已有报告会保留。'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "找不到程序文件：$sourcePath"
}
if ((Test-Path -LiteralPath $installDir) -and -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "安装目录已存在但不是本项目管理的安装：$installDir"
}
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.Project -ne 'software-update-manager' -or $manifest.Version -ne '0.1.0') {
        throw "安装记录不匹配：$manifestPath"
    }
}
if (Test-Path -LiteralPath $programPath) {
    $installedHash = (Get-FileHash -LiteralPath $programPath -Algorithm SHA256).Hash
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($installedHash -ne $sourceHash) {
        throw "已安装程序与当前项目文件不同，请先备份并处理：$programPath"
    }
}
if (Test-Path -LiteralPath $desktopPath) {
    $currentLauncher = [IO.File]::ReadAllText($desktopPath, [Text.Encoding]::ASCII)
    if ($currentLauncher -ne $launcher) {
        throw "桌面入口已存在且内容不同：$desktopPath"
    }
}

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    $action = @($existingTask.Actions)[0]
    $triggers = @($existingTask.Triggers)
    if ($action.Execute -ne 'powershell.exe' -or $action.Arguments -ne $taskArguments -or
        $triggers.Count -ne 1 -or $triggers[0].CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger' -or
        $triggers[0].Delay -ne 'PT1M') {
        throw "同名任务已存在且不是本项目的任务：$taskName"
    }
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $programPath)) {
    Copy-Item -LiteralPath $sourcePath -Destination $programPath -ErrorAction Stop
}
if (-not (Test-Path -LiteralPath $desktopPath)) {
    [IO.File]::WriteAllText($desktopPath, $launcher, [Text.Encoding]::ASCII)
}

@{
    Project = 'software-update-manager'
    Version = '0.1.0'
    ProgramHash = (Get-FileHash -LiteralPath $programPath -Algorithm SHA256).Hash
} | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if (-not $existingTask) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $taskUser
    $trigger.Delay = 'PT1M'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArguments
    $principal = New-ScheduledTaskPrincipal -UserId $taskUser -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description '检查 Winget 和 Scoop 更新，仅在有更新时通知。' | Out-Null
}

Write-Host '安装完成。可从桌面入口打开，或等待下次登录时后台检查。'
