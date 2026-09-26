$ErrorActionPreference = 'Stop'

$installDir = Join-Path $env:USERPROFILE 'SoftwareUpdateManager'
$programPath = Join-Path $installDir 'SoftwareUpdateManager.ps1'
$reportPath = Join-Path $installDir 'software-updates-latest.txt'
$manifestPath = Join-Path $installDir 'install.json'
$desktopPaths = @(
    (Join-Path (Join-Path $env:USERPROFILE 'Desktop') 'UpdatePing.cmd'),
    (Join-Path (Join-Path $env:USERPROFILE 'Desktop') 'Software Update Manager.cmd')
)
$taskName = 'SoftwareUpdateManager-v0.1.0'
$taskArguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $programPath + '" -CheckOnly'
$launcher = "@echo off`r`npowershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File `"%USERPROFILE%\SoftwareUpdateManager\SoftwareUpdateManager.ps1`"`r`nif errorlevel 1 pause`r`n"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "未找到本项目的安装记录：$manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.Project -ne 'software-update-manager' -or $manifest.Version -ne '0.1.0') {
    throw "安装记录不匹配：$manifestPath"
}
if (Test-Path -LiteralPath $programPath) {
    if ((Get-FileHash -LiteralPath $programPath -Algorithm SHA256).Hash -ne $manifest.ProgramHash) {
        throw "程序文件安装后已修改，请手工确认后再卸载：$programPath"
    }
}
foreach ($desktopPath in $desktopPaths) {
    if (Test-Path -LiteralPath $desktopPath) {
        if ([IO.File]::ReadAllText($desktopPath, [Text.Encoding]::ASCII) -ne $launcher) {
            throw "桌面入口已修改，请手工确认后再卸载：$desktopPath"
        }
    }
}
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    $action = @($existingTask.Actions)[0]
    $triggers = @($existingTask.Triggers)
    if ($action.Execute -ne 'powershell.exe' -or $action.Arguments -ne $taskArguments -or
        $triggers.Count -ne 1 -or $triggers[0].CimClass.CimClassName -ne 'MSFT_TaskLogonTrigger' -or
        $triggers[0].Delay -ne 'PT1M') {
        throw "同名任务已修改，请手工确认后再卸载：$taskName"
    }
}

$removeReport = $false
if (Test-Path -LiteralPath $reportPath) {
    $answer = Read-Host '是否删除报告 software-updates-latest.txt？输入 D 删除，其他输入保留'
    $removeReport = $answer -eq 'D'
}

if ($existingTask) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
foreach ($desktopPath in $desktopPaths) {
    if (Test-Path -LiteralPath $desktopPath) { Remove-Item -LiteralPath $desktopPath }
}
if (Test-Path -LiteralPath $programPath) { Remove-Item -LiteralPath $programPath }
if ($removeReport) { Remove-Item -LiteralPath $reportPath }
Remove-Item -LiteralPath $manifestPath

$identityPath = 'Software\Classes\AppUserModelId\SoftwareUpdateManager'
$identityKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($identityPath)
if ($identityKey) {
    try {
        $removeIdentity = $identityKey.GetValue('DisplayName') -in @('UpdatePing', '软件更新管理器') -and
            $identityKey.ValueCount -eq 1 -and $identityKey.SubKeyCount -eq 0
    }
    finally { $identityKey.Dispose() }
    if ($removeIdentity) {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($identityPath, $false)
    }
}

if (@(Get-ChildItem -LiteralPath $installDir -Force).Count -eq 0) {
    Remove-Item -LiteralPath $installDir
}
Write-Host 'UpdatePing 卸载完成。保留的报告和其他用户文件没有删除。'
