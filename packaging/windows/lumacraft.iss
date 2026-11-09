; 框印工坊 LumaCraft Windows 安装脚本。构建前先把发行版文件夹放到 dist。
#define MyAppName "框印工坊"
#define MyAppNameEn "LumaCraft"
#define MyAppVersion "0.20.1"
#define MyAppPublisher "EnderBull"
#define MyAppURL "https://github.com/EnderBull/LumaCraft"
#define MyAppExeName "lumacraft.exe"
#define SourceDir "..\..\app\dist\LumaCraft-0.20.1-Beta"

[Setup]
AppId={{B7E6C2A1-4D3F-4A8E-9C11-8F2A6B0D4E90}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion} Beta
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir=..\..\app\dist
OutputBaseFilename=LumaCraft-0.20.1-Beta-Setup
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
VersionInfoVersion=0.20.1.66
VersionInfoProductName={#MyAppNameEn}
VersionInfoDescription={#MyAppName} {#MyAppVersion} Beta
VersionInfoCopyright=Copyright (C) 2026 {#MyAppPublisher}
ShowLanguageDialog=auto

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
