@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "DATA=app\local"

echo.
echo 将清除 LumaCraft 在这台电脑上的使用记录，下次打开会回到默认状态。
echo 不会删除内置预设，也不会删除你的照片。
echo.
echo 会删除这些文件（没有的就跳过）：
echo   %DATA%\editor-presets.json     你自己保存的预设
echo   %DATA%\photo-state.json        照片的样式、补填和编辑记录
echo   %DATA%\workspace.json          窗口布局、上次打开的文件夹、收藏
echo   %DATA%\export-settings.json    导出设置
echo.

tasklist /FI "IMAGENAME eq lumacraft.exe" 2>nul | find /I "lumacraft.exe" >nul
if not errorlevel 1 (
  echo 软件还开着。请先完全退出 LumaCraft，再双击这个脚本。
  echo.
  pause
  exit /b 1
)

if not exist "%DATA%" (
  echo 没有找到 %DATA%，可能已经是默认状态。
  echo.
  pause
  exit /b 0
)

call :remove "%DATA%\editor-presets.json"
call :remove "%DATA%\editor-presets.json.pending"
call :remove "%DATA%\photo-state.json"
call :remove "%DATA%\photo-state.json.pending"
call :remove "%DATA%\workspace.json"
call :remove "%DATA%\workspace.json.pending"
call :remove "%DATA%\export-settings.json"
call :remove "%DATA%\export-settings.json.pending"

echo.
echo 清理完成。请重新打开软件。
echo.
pause
exit /b 0

:remove
if exist "%~1" (
  del /f /q "%~1"
  if exist "%~1" (
    echo 删除失败：%~1
  ) else (
    echo 已删除：%~1
  )
)
exit /b 0
