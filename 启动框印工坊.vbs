' 启动框印工坊的最新版本，不显示控制台窗口。
Set shell = CreateObject("WScript.Shell")
script = "D:\AI Agent\LumaCraft\启动框印工坊.ps1"
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """", 0, False
