# 启动框印工坊的最新版本。
#
# 每次打包都会新建一个 dist\LumaCraft-<版本>-Authoring 文件夹，旧版本保留不删。
# 这个脚本按版本号从高到低找，启动最新的那个，所以打包后不需要再改快捷方式。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'app\dist'

if (-not (Test-Path $dist)) {
    [System.Windows.Forms.MessageBox]::Show("找不到 app\dist 文件夹。`n请先打包一次软件。", '框印工坊') | Out-Null
    exit 1
}

# 按版本号排序，而不是按文件夹名或修改时间：0.9.0 要排在 0.10.0 之前。
$newest = Get-ChildItem $dist -Directory -Filter 'LumaCraft-*' |
    Where-Object { $_.Name -match '^LumaCraft-(\d+(?:\.\d+)*)' } |
    Sort-Object {
        $v = [version]($_.Name -replace '^LumaCraft-', '' -replace '-.*$', '')
        $v
    } -Descending |
    Select-Object -First 1

if (-not $newest) {
    [System.Windows.Forms.MessageBox]::Show("app\dist 里没有找到已打包的版本。`n请先打包一次软件。", '框印工坊') | Out-Null
    exit 1
}

$exe = Join-Path $newest.FullName 'lumacraft.exe'
if (-not (Test-Path $exe)) {
    [System.Windows.Forms.MessageBox]::Show("最新版本文件夹里没有 lumacraft.exe：`n$($newest.FullName)", '框印工坊') | Out-Null
    exit 1
}

Start-Process -FilePath $exe -WorkingDirectory $newest.FullName
