# 创建「启动框印工坊」快捷方式
#
# 快捷方式含本机绝对路径，不进版本库；这个脚本负责在换电脑或误删后重建。
#
# 用法：右键「使用 PowerShell 运行」，或在 PowerShell 里执行本文件。

$ErrorActionPreference = 'Stop'
# 本脚本在 tools\ 里：项目根目录是上一级，vbs 与本脚本同目录，
# 快捷方式要放回根目录（那里是用户双击的位置）。
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $toolsDir
$link = Join-Path $root '启动框印工坊.lnk'
$vbs = Join-Path $toolsDir '启动框印工坊.vbs'

if (-not (Test-Path $vbs)) {
    Write-Host "缺少 启动框印工坊.vbs，无法创建快捷方式。" -ForegroundColor Red
    exit 1
}

$dist = Join-Path $root 'app\dist'
$newest = Get-ChildItem $dist -Directory -Filter 'LumaCraft-*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^LumaCraft-(\d+(?:\.\d+)*)' } |
    Sort-Object { [version]($_.Name -replace '^LumaCraft-', '' -replace '-.*$', '') } -Descending |
    Select-Object -First 1

# 图标取自最新版本的 exe；还没有打包过就不设图标。
$icon = if ($newest) { Join-Path $newest.FullName 'lumacraft.exe' } else { '' }

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($link)
# wscript 运行 vbs，双击时不会闪出黑色控制台窗口。
$sc.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
$sc.Arguments = "`"$vbs`""
$sc.WorkingDirectory = $root
if ($icon -and (Test-Path $icon)) { $sc.IconLocation = "$icon,0" }
$sc.Description = '启动框印工坊（自动使用最新版本）'
$sc.Save()

Write-Host "已创建快捷方式：$link" -ForegroundColor Green
if ($newest) {
    Write-Host "当前会启动：$($newest.Name)"
} else {
    Write-Host "还没打包过任何版本，打包后快捷方式才能用。" -ForegroundColor Yellow
}
