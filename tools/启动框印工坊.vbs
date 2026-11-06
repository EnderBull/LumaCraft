' 启动框印工坊的最新版本，不显示控制台窗口。
'
' 路径按本文件所在位置推算，不写死绝对路径：
' 本文件在 <项目>\tools\ 下，启动脚本与它同目录。

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

script = fso.GetParentFolderName(WScript.ScriptFullName) & "\启动框印工坊.ps1"

If Not fso.FileExists(script) Then
    MsgBox "找不到启动脚本：" & vbCrLf & script, vbExclamation, "框印工坊"
    WScript.Quit 1
End If

shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """", 0, False
