# Run in PowerShell before using the project-local Android tools:
# . .\tools\android-p0-env.ps1
$androidP0Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../.toolchain/android-p0')).Path
$androidP0Jdk = @(Get-ChildItem -LiteralPath (Join-Path $androidP0Root 'jdk') -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin/javac.exe') })
if ($androidP0Jdk.Count -ne 1) {
    throw "Expected one JDK in $androidP0Root\jdk"
}

$env:JAVA_HOME = $androidP0Jdk[0].FullName
$env:ANDROID_HOME = Join-Path $androidP0Root 'sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $androidP0Root 'user'
$env:ANDROID_AVD_HOME = Join-Path $env:ANDROID_USER_HOME 'avd'
$env:GRADLE_USER_HOME = Join-Path $androidP0Root 'gradle'
$env:PUB_CACHE = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../.toolchain/pub-cache')).Path
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'

$androidP0Bins = @(
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../.toolchain/flutter/bin')).Path
    (Join-Path $env:JAVA_HOME 'bin')
    (Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin')
    (Join-Path $env:ANDROID_HOME 'platform-tools')
    (Join-Path $env:ANDROID_HOME 'emulator')
)
$env:Path = ($androidP0Bins + ($env:Path -split ';') |
    Select-Object -Unique) -join ';'
