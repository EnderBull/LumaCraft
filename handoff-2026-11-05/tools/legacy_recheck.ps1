$projectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$appRoot=Join-Path $projectRoot 'app'
$evidence=Join-Path $projectRoot 'handoff-2026-11-05/evidence'
$env:PUB_CACHE=Join-Path $appRoot '.toolchain/pub-cache'
$dart=Join-Path $appRoot '.toolchain/flutter/bin/cache/dart-sdk/bin/dart.exe'
$results=[System.Collections.Generic.List[object]]::new()
foreach($old in @(Get-Content -LiteralPath (Join-Path $evidence 'command-results.json') -Raw | ConvertFrom-Json)){$results.Add($old)}
foreach($name in @('check','workspace_io_check')){
 $cwd=Join-Path $appRoot 'test/core'
 $log=Join-Path $evidence ('legacy-'+$name+'-direct.log')
 $started=(Get-Date).ToString('o')
 Push-Location -LiteralPath $cwd
 & $dart run ($name+'.dart') *> $log
 $code=$LASTEXITCODE
 Pop-Location
 $results.Add([pscustomobject]@{Name='legacy-'+$name+'-direct';Command="& '$dart' run $name.dart";Executable=$dart;Arguments=@('run',($name+'.dart'));Cwd=$cwd;Start=$started;End=(Get-Date).ToString('o');ExitCode=$code;Log=$log;Environment=@{PUB_CACHE=$env:PUB_CACHE}})
 Write-Output ($name+': exit '+$code)
}
$log=Join-Path $evidence 'analyzer-config.log'
Push-Location -LiteralPath $appRoot
& $dart analyze analysis_options.yaml *> $log
$code=$LASTEXITCODE
Pop-Location
$results.Add([pscustomobject]@{Name='analyzer-config';Command="& '$dart' analyze analysis_options.yaml";Cwd=$appRoot;ExitCode=$code;Log=$log})
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'command-results.json') -Encoding utf8
Get-Content -LiteralPath $log
