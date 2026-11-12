@echo off
setlocal
set "LUMACRAFT_EMULATOR_ENV=%~dp0android-p0-env.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; . $env:LUMACRAFT_EMULATOR_ENV; & (Join-Path $env:ANDROID_HOME 'emulator/emulator.exe') -avd LumaCraft_API_31 -no-metrics -no-snapshot -gpu swiftshader -feature -Vulkan; exit $LASTEXITCODE"
if errorlevel 1 (
    echo.
    echo Android Emulator failed to start. See the output above.
    pause
    exit /b 1
)
