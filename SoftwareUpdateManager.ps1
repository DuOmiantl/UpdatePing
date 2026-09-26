param(
    [switch]$CheckOnly
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path $ScriptDir "software-updates-latest.txt"

function Remove-Ansi {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return $Text -replace "$([char]27)\[[0-9;?]*[ -/]*[@-~]", ""
}

function Invoke-NativeUtf8 {
    param(
        [string]$FilePath,
        [string]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
    } catch {}

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    try {
        [void]$p.Start()
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        return [pscustomobject]@{
            ExitCode = $p.ExitCode
            Output   = $stdout
            Error    = $stderr
        }
    }
    catch {
        return [pscustomobject]@{
            ExitCode = -1
            Output   = ""
            Error    = $_.Exception.Message
        }
    }
    finally {
        if ($p) { $p.Dispose() }
    }
}

function Get-WingetUpdates {
    $items = @()

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $items
    }

    $result = Invoke-NativeUtf8 `
        -FilePath "winget.exe" `
        -Arguments "list --upgrade-available --accept-source-agreements --disable-interactivity"

    if ($result.ExitCode -ne 0) {
        throw "Winget 检查失败（退出码 $($result.ExitCode)）：$($result.Error.Trim())"
    }

    $text = Remove-Ansi (($result.Output + "`n" + $result.Error).Trim())
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $items
    }

    $lines = $text -split "`r?`n"
    $afterSeparator = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*-{10,}\s*$') {
            $afterSeparator = $true
            continue
        }

        if (-not $afterSeparator) { continue }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # 主要解析方式：Winget 表格列之间通常至少有两个空格
        if ($line -match '^(?<Name>.+?)\s{2,}(?<Id>\S+)\s{2,}(?<Installed>\S+)\s{2,}(?<Available>\S+)\s{2,}(?<Source>\S+)\s*$') {
            $items += [pscustomobject]@{
                Manager   = "Winget"
                Name      = $matches.Name.Trim()
                Id        = $matches.Id.Trim()
                Installed = $matches.Installed.Trim()
                Available = $matches.Available.Trim()
                Source    = $matches.Source.Trim()
            }
            continue
        }

        # 兼容某些列距较窄的输出；要求最后一列是常见来源
        if ($line -match '^(?<Name>.+?)\s+(?<Id>[A-Za-z0-9][A-Za-z0-9._+\-]+)\s+(?<Installed>\S+)\s+(?<Available>\S+)\s+(?<Source>winget|msstore)\s*$') {
            $items += [pscustomobject]@{
                Manager   = "Winget"
                Name      = $matches.Name.Trim()
                Id        = $matches.Id.Trim()
                Installed = $matches.Installed.Trim()
                Available = $matches.Available.Trim()
                Source    = $matches.Source.Trim()
            }
        }
    }

    return $items
}

function Get-ScoopUpdates {
    $items = @()

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        return $items
    }

    # 仅刷新 Scoop / bucket 元数据；不会执行 scoop update *
    & scoop update *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Scoop 元数据刷新失败（退出码 $LASTEXITCODE）。"
    }

    $raw = (& scoop status 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Scoop 检查失败（退出码 $LASTEXITCODE）：$raw"
    }
    $text = Remove-Ansi $raw

    if ($text -match '(?i)Scoop is up to date' -or
        $text -match '(?i)Everything is ok') {
        return $items
    }

    $lines = $text -split "`r?`n"
    $afterSeparator = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*-{3,}\s+') {
            $afterSeparator = $true
            continue
        }

        if (-not $afterSeparator) { continue }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Scoop 包名本身不含空格，因此取前三列即可
        if ($line -match '^\s*(?<Name>[A-Za-z0-9._+\-]+)\s+(?<Installed>\S+)\s+(?<Available>\S+)') {
            if ($matches.Name -notin @("Name", "----")) {
                $items += [pscustomobject]@{
                    Manager   = "Scoop"
                    Name      = $matches.Name.Trim()
                    Id        = $matches.Name.Trim()
                    Installed = $matches.Installed.Trim()
                    Available = $matches.Available.Trim()
                    Source    = "scoop"
                }
            }
        }
    }

    return $items
}

function Write-ReadableReport {
    param(
        [array]$WingetItems,
        [array]$ScoopItems
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("UpdatePing 软件更新报告")
    $lines.Add("生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("Winget：$($WingetItems.Count) 项待更新")
    $lines.Add("Scoop：$($ScoopItems.Count) 项待更新")
    $lines.Add("")

    foreach ($group in @(
        @{ Name = 'Winget'; Items = $WingetItems },
        @{ Name = 'Scoop'; Items = $ScoopItems }
    )) {
        $lines.Add("========== $($group.Name) ==========")
        if ($group.Items.Count -eq 0) {
            $lines.Add("当前没有可更新的软件。")
        } else {
            $i = 1
            foreach ($item in $group.Items) {
                $lines.Add(("{0}. {1}" -f $i, $item.Name))
                $lines.Add(("   当前版本：{0}" -f $item.Installed))
                $lines.Add(("   可用版本：{0}" -f $item.Available))
                if ($group.Name -eq 'Winget') {
                    $lines.Add(("   包 ID：{0}" -f $item.Id))
                    $lines.Add(("   来源：{0}" -f $item.Source))
                }
                $lines.Add("")
                $i++
            }
        }
        $lines.Add("")
    }

    # Windows PowerShell 5.1 的 UTF8 带 BOM，记事本识别中文最稳
    $lines | Set-Content -Path $ReportPath -Encoding UTF8 -ErrorAction Stop
}

function Show-ToastNotice {
    param(
        [string]$Title,
        [string]$Message
    )

    $ErrorActionPreference = 'Stop'
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.UI.Notifications.ToastNotifier, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.UI.Notifications.NotificationSetting, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $appId = 'SoftwareUpdateManager'
    $identityPath = 'HKCU:\Software\Classes\AppUserModelId\' + $appId
    if (-not (Test-Path -LiteralPath $identityPath)) {
        New-Item -Path $identityPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $identityPath -Name DisplayName -Value 'UpdatePing' -PropertyType String -Force | Out-Null

    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml('<toast><visual><binding template="ToastGeneric"><text></text><text></text></binding></visual></toast>')
    $textNodes = $xml.GetElementsByTagName('text')
    [void]$textNodes.Item(0).AppendChild($xml.CreateTextNode($Title))
    [void]$textNodes.Item(1).AppendChild($xml.CreateTextNode($Message))

    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $toast.Tag = 'updates'
    $toast.Group = 'SoftwareUpdateManager'
    $notifier.Show($toast)

    # 首次发送前，Windows 可能尚未初始化此应用的通知设置。
    $setting = $notifier.get_Setting()
    if ($setting.ToString() -ne 'Enabled') {
        throw "Windows Toast 不可用：$setting"
    }
}

function Show-BalloonNotice {
    param(
        [string]$Title,
        [string]$Message
    )

    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $notify = New-Object System.Windows.Forms.NotifyIcon
    try {
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true

        $openReport = {
            try {
                if (Test-Path -LiteralPath $ReportPath) {
                    Start-Process notepad.exe "`"$ReportPath`"" -ErrorAction Stop
                }
            }
            catch {
                [Console]::Error.WriteLine("打开报告失败：$($_.Exception.Message)")
            }
        }

        $notify.add_BalloonTipClicked($openReport)
        $notify.ShowBalloonTip(10000)

        # 只在即时弹窗存在期间支持点击；报告文件会一直保留到下次检查覆盖
        $until = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $until) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
    }
    finally {
        $notify.Dispose()
    }
}

function Show-Notice {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        Show-ToastNotice -Title $Title -Message $Message
        return
    }
    catch {
        [Console]::Error.WriteLine("Toast 通知失败，将尝试托盘通知：$($_.Exception.Message)")
    }

    try {
        Show-BalloonNotice -Title $Title -Message $Message
    }
    catch {
        [Console]::Error.WriteLine("托盘通知失败，更新报告仍可查看：$($_.Exception.Message)")
    }
}

function Get-AllUpdates {
    $scoopItems = @(Get-ScoopUpdates)
    $wingetItems = @(Get-WingetUpdates)

    Write-ReadableReport -WingetItems $wingetItems -ScoopItems $scoopItems

    return [pscustomobject]@{
        Winget = $wingetItems
        Scoop  = $scoopItems
    }
}

if ($CheckOnly) {
    try {
        $updates = Get-AllUpdates

        $parts = @()
        if ($updates.Scoop.Count -gt 0) {
            $parts += "Scoop：$($updates.Scoop.Count) 项可更新"
        }
        if ($updates.Winget.Count -gt 0) {
            $parts += "Winget：$($updates.Winget.Count) 项可更新"
        }

        if ($parts.Count -gt 0) {
            Show-Notice `
                -Title "UpdatePing" `
                -Message (($parts -join "`n") + "`n打开 UpdatePing，查看并选择需要更新的软件。")
        }
    }
    catch {
        [Console]::Error.WriteLine("后台检查失败：$($_.Exception.Message)")
        exit 1
    }

    exit 0
}

# ==============================
# GUI
# ==============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "UpdatePing"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(980, 650)
$form.MinimumSize = New-Object System.Drawing.Size(860, 520)

$summary = New-Object System.Windows.Forms.Label
$summary.AutoSize = $true
$summary.Location = New-Object System.Drawing.Point(14, 15)
$summary.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$summary.Text = "正在准备..."
$form.Controls.Add($summary)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(14, 48)
$grid.Size = New-Object System.Drawing.Size(935, 490)
$grid.Anchor = "Top,Bottom,Left,Right"
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.MultiSelect = $false
$grid.SelectionMode = "FullRowSelect"
$grid.RowHeadersVisible = $false
$grid.AutoSizeColumnsMode = "Fill"
$grid.BackgroundColor = [System.Drawing.SystemColors]::Window
$form.Controls.Add($grid)

$colCheck = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colCheck.HeaderText = "选择"
$colCheck.Width = 50
$colCheck.FillWeight = 35
[void]$grid.Columns.Add($colCheck)

$columns = @(
    @("管理器", 55),
    @("软件", 170),
    @("当前版本", 90),
    @("可用版本", 90),
    @("包 ID", 180),
    @("来源", 65)
)

foreach ($c in $columns) {
    $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col.HeaderText = $c[0]
    $col.ReadOnly = $true
    $col.FillWeight = $c[1]
    [void]$grid.Columns.Add($col)
}

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "重新检查"
$btnRefresh.Location = New-Object System.Drawing.Point(14, 553)
$btnRefresh.Size = New-Object System.Drawing.Size(95, 34)
$btnRefresh.Anchor = "Bottom,Left"
$form.Controls.Add($btnRefresh)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = "全选"
$btnAll.Location = New-Object System.Drawing.Point(120, 553)
$btnAll.Size = New-Object System.Drawing.Size(75, 34)
$btnAll.Anchor = "Bottom,Left"
$form.Controls.Add($btnAll)

$btnNone = New-Object System.Windows.Forms.Button
$btnNone.Text = "清空"
$btnNone.Location = New-Object System.Drawing.Point(205, 553)
$btnNone.Size = New-Object System.Drawing.Size(75, 34)
$btnNone.Anchor = "Bottom,Left"
$form.Controls.Add($btnNone)

$btnReport = New-Object System.Windows.Forms.Button
$btnReport.Text = "打开报告"
$btnReport.Location = New-Object System.Drawing.Point(290, 553)
$btnReport.Size = New-Object System.Drawing.Size(95, 34)
$btnReport.Anchor = "Bottom,Left"
$form.Controls.Add($btnReport)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "更新所选"
$btnUpdate.Location = New-Object System.Drawing.Point(747, 553)
$btnUpdate.Size = New-Object System.Drawing.Size(95, 34)
$btnUpdate.Anchor = "Bottom,Right"
$form.Controls.Add($btnUpdate)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "关闭"
$btnClose.Location = New-Object System.Drawing.Point(852, 553)
$btnClose.Size = New-Object System.Drawing.Size(95, 34)
$btnClose.Anchor = "Bottom,Right"
$form.Controls.Add($btnClose)

function Refresh-Grid {
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $btnRefresh.Enabled = $false
    $summary.Text = "正在检查 Scoop 和 Winget，请稍候..."
    $grid.Rows.Clear()

    try {
        $updates = Get-AllUpdates

        foreach ($item in $updates.Winget) {
            [void]$grid.Rows.Add(
                $false,
                "Winget",
                $item.Name,
                $item.Installed,
                $item.Available,
                $item.Id,
                $item.Source
            )
        }

        foreach ($item in $updates.Scoop) {
            [void]$grid.Rows.Add(
                $false,
                "Scoop",
                $item.Name,
                $item.Installed,
                $item.Available,
                $item.Id,
                $item.Source
            )
        }

        $total = $updates.Winget.Count + $updates.Scoop.Count
        $summary.Text = "共发现 $total 项更新（Winget $($updates.Winget.Count)；Scoop $($updates.Scoop.Count)）。勾选后点《更新所选》。"
    }
    catch {
        $summary.Text = "检查失败：$($_.Exception.Message)"
    }
    finally {
        $btnRefresh.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

$btnRefresh.Add_Click({ Refresh-Grid })

$btnAll.Add_Click({
    foreach ($row in $grid.Rows) {
        $row.Cells[0].Value = $true
    }
})

$btnNone.Add_Click({
    foreach ($row in $grid.Rows) {
        $row.Cells[0].Value = $false
    }
})

$btnReport.Add_Click({
    if (Test-Path $ReportPath) {
        Start-Process notepad.exe "`"$ReportPath`""
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "还没有生成报告，请先点《重新检查》。",
            "UpdatePing",
            "OK",
            "Information"
        ) | Out-Null
    }
})

$btnClose.Add_Click({ $form.Close() })

$btnUpdate.Add_Click({
    # 确保当前复选框编辑值提交
    $grid.EndEdit()

    $selected = @()
    foreach ($row in $grid.Rows) {
        if ($row.Cells[0].Value -eq $true) {
            $selected += [pscustomobject]@{
                Manager = [string]$row.Cells[1].Value
                Name    = [string]$row.Cells[2].Value
                Id      = [string]$row.Cells[5].Value
            }
        }
    }

    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "请先勾选至少一个软件。",
            "UpdatePing",
            "OK",
            "Information"
        ) | Out-Null
        return
    }

    $previewNames = @($selected | Select-Object -First 12 | ForEach-Object { "• " + $_.Name })
    if ($selected.Count -gt 12) {
        $previewNames += "……以及另外 $($selected.Count - 12) 项"
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        ("准备更新以下软件：`n`n" + ($previewNames -join "`n") + "`n`n继续吗？"),
        "确认更新",
        "YesNo",
        "Question"
    )

    if ($confirm -ne "Yes") { return }

    $tempScript = Join-Path $env:TEMP ("software-update-selected-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    $commands = New-Object System.Collections.Generic.List[string]

    $commands.Add('$ErrorActionPreference = "Continue"')
    $commands.Add('Write-Host "开始更新所选软件..." -ForegroundColor Cyan')
    $commands.Add('')

    foreach ($item in $selected) {
        $safeName = $item.Name.Replace("'", "''")
        $safeId = $item.Id.Replace("'", "''")

        if ($item.Manager -eq "Winget") {
            $commands.Add(("Write-Host '`n[Winget] {0}' -ForegroundColor Yellow" -f $safeName))
            $commands.Add(("winget upgrade --id '{0}' --exact --accept-source-agreements --accept-package-agreements" -f $safeId))
        }
        elseif ($item.Manager -eq "Scoop") {
            $commands.Add(("Write-Host '`n[Scoop] {0}' -ForegroundColor Yellow" -f $safeName))
            $commands.Add(("scoop update '{0}'" -f $safeId))
        }
    }

    $commands.Add('')
    $commands.Add('Write-Host "`n所选更新任务已执行完。建议回到 UpdatePing 点《重新检查》确认结果。" -ForegroundColor Green')
    $commands.Add('Read-Host "按 Enter 关闭此窗口"')

    $commands | Set-Content -Path $tempScript -Encoding UTF8

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$tempScript`""
        )

    [System.Windows.Forms.MessageBox]::Show(
        "已打开更新窗口。更新完成后回到这里点《重新检查》即可。",
        "UpdatePing",
        "OK",
        "Information"
    ) | Out-Null
})

$form.Add_Shown({ Refresh-Grid })
[void]$form.ShowDialog()
