param(
  [Parameter(Mandatory = $true)][string]$UnsignedApk,
  [Parameter(Mandatory = $true)][string]$SignedApk,
  [string]$KeyStore = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'LumaCraft/Signing/lumacraft-release.p12')
)
$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Action) {
  if ($LASTEXITCODE -ne 0) { throw "$Action failed (exit code $LASTEXITCODE)." }
}

. (Join-Path $PSScriptRoot 'android-p0-env.ps1')
$UnsignedApk = (Resolve-Path -LiteralPath $UnsignedApk).Path
$SignedApk = [IO.Path]::GetFullPath($SignedApk)
if (Test-Path -LiteralPath $SignedApk) { throw "Signed APK already exists: $SignedApk" }
$pending = "$SignedApk.pending"

$buildTools = Join-Path $env:ANDROID_HOME 'build-tools/36.0.0'
$apkSigner = Join-Path $buildTools 'apksigner.bat'
$zipalign = Join-Path $buildTools 'zipalign.exe'
& $zipalign -c -P 16 4 $UnsignedApk
Assert-NativeSuccess 'Unsigned APK alignment'
$badging = & (Join-Path $buildTools 'aapt2.exe') dump badging $UnsignedApk
Assert-NativeSuccess 'APK manifest check'
if (!(($badging -join "`n") -match "(?m)^package: name='io\.github\.enderbull\.lumacraft' ")) {
  throw 'This APK does not have the LumaCraft release application ID.'
}

$KeyStore = [IO.Path]::GetFullPath($KeyStore)
$alias = 'lumacraft-release'
if (!(Test-Path -LiteralPath $KeyStore)) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $KeyStore) -Force | Out-Null
  Write-Host "Creating release keystore: $KeyStore"
  & (Join-Path $env:JAVA_HOME 'bin/keytool.exe') -genkeypair -keystore $KeyStore -storetype PKCS12 -alias $alias -keyalg RSA -keysize 4096 -validity 10950 -dname 'CN=LumaCraft'
  Assert-NativeSuccess 'Key creation'
}
Write-Host 'Enter the keystore password to sign the APK.'
& $apkSigner sign --ks $KeyStore --ks-key-alias $alias --v4-signing-enabled false --out $pending $UnsignedApk
Assert-NativeSuccess 'APK signing'
& $apkSigner verify --verbose --print-certs $pending
Assert-NativeSuccess 'APK signature verification'
& $zipalign -c -P 16 4 $pending
Assert-NativeSuccess 'Signed APK alignment'
Move-Item -LiteralPath $pending -Destination $SignedApk
Get-FileHash -LiteralPath $SignedApk -Algorithm SHA256 | Format-List
Write-Host "Install this APK: $SignedApk"
Write-Host "Back up this keystore separately: $KeyStore"
