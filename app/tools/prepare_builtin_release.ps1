param([Parameter(Mandatory=$true)][string]$InputLibrary)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$source=Get-Item -LiteralPath $InputLibrary
if($source.Length -gt 64MB){throw '内置库超过64MB'}
$library=Get-Content -LiteralPath $source.FullName -Raw -Encoding utf8 | ConvertFrom-Json
if($library.format -ne 'LumaCraftBuiltinLibrary' -or $library.version -ne 1 -or @($library.presets).Count -eq 0){throw '不是支持的内置预设库'}
$name='release-'+(Get-Date -Format 'yyyyMMdd-HHmmss-ffff')+'.json'
$target=Join-Path $projectRoot ('assets/builtins/'+$name)
if(Test-Path -LiteralPath $target){throw '目标已存在，停止以保留原文件'}
Copy-Item -LiteralPath $source.FullName -Destination $target
Write-Output "已准备独立资源：$target"
Write-Output '下一步在app目录构建发行版，制作入口默认关闭：'
Write-Output ('.toolchain/flutter/bin/flutter.bat build windows --release --dart-define=LUMACRAFT_AUTHORING=false --dart-define=LUMACRAFT_BUILTIN_ASSET=assets/builtins/'+$name)
Write-Output '构建前应运行内置库核心校验；软件加载时仍执行完整结构校验。原资源及本机工作库均保留。'
