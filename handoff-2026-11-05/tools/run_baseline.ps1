$ErrorActionPreference='Continue'
$projectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$appRoot=Join-Path $projectRoot 'app'
$evidence=Join-Path $projectRoot 'handoff-2026-11-05/evidence'
$env:PUB_CACHE=Join-Path $appRoot '.toolchain/pub-cache'
$env:LUMACRAFT_DATA_DIR=Join-Path $evidence ('export-ui-check-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$env:LUMACRAFT_COLOR_TOOL=Join-Path $appRoot 'build/windows/x64/runner/Release/lumacraft_color_tool.exe'
$flutter=Join-Path $appRoot '.toolchain/flutter/bin/flutter.bat'
$dart=Join-Path $appRoot '.toolchain/flutter/bin/cache/dart-sdk/bin/dart.exe'
$results=[System.Collections.Generic.List[object]]::new()
function Invoke-Recorded {
 param([string]$Name,[string]$Program,[string[]]$CommandArguments,[string]$WorkingDirectory=$appRoot)
 $log=Join-Path $evidence ($Name+'.log')
 $start=(Get-Date).ToString('o')
 $display="& '"+$Program+"' "+(($CommandArguments | ForEach-Object {"'"+$_.Replace("'","''")+"'"}) -join ' ')
 Push-Location -LiteralPath $WorkingDirectory
 try { & $Program @CommandArguments *> $log; $code=$LASTEXITCODE }
 catch { $_ | Out-File -LiteralPath $log -Append -Encoding utf8; $code=-1 }
 finally {Pop-Location}
 $entry=[pscustomobject]@{Name=$Name;Command=$display;Executable=$Program;Arguments=$CommandArguments;Cwd=$WorkingDirectory;Start=$start;End=(Get-Date).ToString('o');ExitCode=$code;Log=$log;Environment=@{PUB_CACHE=$env:PUB_CACHE;LUMACRAFT_DATA_DIR=$env:LUMACRAFT_DATA_DIR;LUMACRAFT_COLOR_TOOL=$env:LUMACRAFT_COLOR_TOOL}}
 $results.Add($entry)
 $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'command-results.json') -Encoding utf8
 Write-Output ($Name+': exit '+$code)
}
Invoke-Recorded -Name 'git-project' -Program 'git' -CommandArguments @('-C',$projectRoot,'rev-parse','--show-toplevel') -WorkingDirectory $projectRoot
Invoke-Recorded -Name 'flutter-version' -Program $flutter -CommandArguments @('--version','--machine')
Invoke-Recorded -Name 'flutter-doctor' -Program $flutter -CommandArguments @('doctor','-v')
Invoke-Recorded -Name 'dart-analysis' -Program $dart -CommandArguments @('analyze','lib','test')
Invoke-Recorded -Name 'flutter-tests' -Program $flutter -CommandArguments @('test','--no-pub','--reporter','expanded')
Invoke-Recorded -Name 'preview-export' -Program $flutter -CommandArguments @('test','--no-pub','build/export-preview/preview_test.dart','--reporter','expanded')
Invoke-Recorded -Name 'preview-builtins' -Program $flutter -CommandArguments @('test','--no-pub','build/builtin-preview/preview_test.dart','--reporter','expanded')
$legacy=Join-Path $evidence 'legacy-core-working'
New-Item -ItemType Directory -Path $legacy -Force | Out-Null
Invoke-Recorded -Name 'legacy-core' -Program $dart -CommandArguments @('--packages='+ (Join-Path $appRoot 'test/core/.dart_tool/package_config.json'),(Join-Path $appRoot 'test/core/check.dart')) -WorkingDirectory $legacy
Invoke-Recorded -Name 'legacy-directory' -Program $dart -CommandArguments @('--packages='+ (Join-Path $appRoot 'test/core/.dart_tool/package_config.json'),(Join-Path $appRoot 'test/core/workspace_io_check.dart')) -WorkingDirectory $legacy
Invoke-Recorded -Name 'windows-authoring-build' -Program $flutter -CommandArguments @('build','windows','--release','--no-pub','--dart-define=LUMACRAFT_AUTHORING=true')
